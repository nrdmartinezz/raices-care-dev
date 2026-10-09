import { logger } from "firebase-functions";

import gardenNames from "./vernacular_aliases.json";

/** Ranks below genus. A genus hit is not a species we can hand to Trefle. */
const SPECIES_RANKS = new Set([
  "species",
  "subspecies",
  "variety",
  "form",
  "hybrid",
]);

/**
 * Lookup key for a typed plant name.
 *
 * Accents and punctuation collapse so "Albahaca" and "snake-plant" share a
 * key with the shipped list.
 */
export function normalizeVernacular(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/ +/g, " ");
}

const GARDEN_NAMES: ReadonlyMap<string, string> = new Map(
  Object.entries(gardenNames)
    .map(([name, scientific]) => [normalizeVernacular(name), scientific.trim()] as const)
    .filter((entry) => entry[0].length >= 2 && entry[1].length > 0),
);

/** Scientific name from the shipped garden list, or null when the key is absent. */
export function lookupGardenName(normalized: string): string | null {
  return GARDEN_NAMES.get(normalized) ?? null;
}

export interface SlugMatch {
  slug: string;
  common_name: string | null;
}

/**
 * Alias-search hits come first. The same slug is kept once.
 * The first alias hit with no common name takes the name the person typed.
 */
export function mergeBySlug<T extends SlugMatch>(
  aliasHits: readonly T[],
  directHits: readonly T[],
  matchedName: string | null,
): T[] {
  const seen = new Set<string>();
  const merged: T[] = [];

  const push = (match: T, fillName: boolean) => {
    if (seen.has(match.slug)) {
      return;
    }
    seen.add(match.slug);
    if (fillName && !match.common_name && matchedName) {
      merged.push({ ...match, common_name: matchedName });
      return;
    }
    merged.push(match);
  };

  aliasHits.forEach((match, index) => push(match, index === 0));
  for (const match of directHits) {
    push(match, false);
  }
  return merged;
}

/**
 * First species-or-below scientific name from iNaturalist autocomplete.
 * A miss or a transport failure returns null so search can continue.
 */
export async function fetchInaturalistScientificName(
  query: string,
): Promise<string | null> {
  const term = query.trim();
  if (term.length < 2) {
    return null;
  }

  try {
    const response = await fetch(
      `https://api.inaturalist.org/v1/taxa/autocomplete?q=${encodeURIComponent(term)}`,
      {
        headers: {
          Accept: "application/json",
          "User-Agent": "RaicesGarden/1.0 (catalog search)",
        },
        signal: AbortSignal.timeout(5000),
      },
    );
    if (!response.ok) {
      logger.warn("iNaturalist lookup failed", { status: response.status });
      return null;
    }

    const payload = (await response.json()) as {
      results?: Array<{ name?: string; rank?: string }>;
    };
    for (const taxon of payload.results ?? []) {
      const name = taxon.name?.trim();
      if (!name || !name.includes(" ")) {
        continue;
      }
      if (!taxon.rank || !SPECIES_RANKS.has(taxon.rank)) {
        continue;
      }
      return name;
    }
    return null;
  } catch (error) {
    logger.warn("iNaturalist lookup failed", error);
    return null;
  }
}

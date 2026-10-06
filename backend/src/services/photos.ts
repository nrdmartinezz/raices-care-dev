import { MAX_PHOTO_BYTES } from "../env";
import { ApiError } from "../http/errors";

export type SniffedImage = {
  contentType: "image/jpeg" | "image/png" | "image/webp" | "image/heic";
  extension: "jpg" | "png" | "webp" | "heic";
};

export function sniffImage(bytes: Uint8Array): SniffedImage {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return { contentType: "image/jpeg", extension: "jpg" };
  }
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47
  ) {
    return { contentType: "image/png", extension: "png" };
  }
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return { contentType: "image/webp", extension: "webp" };
  }
  if (bytes.length >= 12) {
    const brand = String.fromCharCode(bytes[8], bytes[9], bytes[10], bytes[11]);
    const box = String.fromCharCode(bytes[4], bytes[5], bytes[6], bytes[7]);
    if (box === "ftyp" && ["heic", "heif", "mif1", "msf1"].includes(brand)) {
      return { contentType: "image/heic", extension: "heic" };
    }
  }
  throw new ApiError(415, "unsupported_media_type", "Upload a JPEG, PNG, WebP, or HEIC image.");
}

export async function readImageBody(request: Request): Promise<Uint8Array> {
  const declared = request.headers.get("content-length");
  if (declared && Number(declared) > MAX_PHOTO_BYTES) {
    throw new ApiError(413, "payload_too_large", "Images must be 10 MB or smaller.");
  }
  const buffer = await request.arrayBuffer();
  if (buffer.byteLength > MAX_PHOTO_BYTES) {
    throw new ApiError(413, "payload_too_large", "Images must be 10 MB or smaller.");
  }
  if (buffer.byteLength === 0) {
    throw new ApiError(400, "validation_error", "Image body is empty.");
  }
  return new Uint8Array(buffer);
}

export function plantPhotoKey(
  userId: string,
  plantId: string,
  photoId: string,
  extension: string,
): string {
  return `users/${userId}/plants/${plantId}/${photoId}.${extension}`;
}

export function avatarKey(userId: string): string {
  return `users/${userId}/profile/avatar.jpg`;
}

export async function deleteObject(bucket: R2Bucket, key: string): Promise<void> {
  await bucket.delete(key);
}

/** Retries object deletion for photos soft-deleted more than a day ago. */
export async function cleanupDeletedPhotos(env: {
  DB: D1Database;
  IMAGES: R2Bucket;
}): Promise<number> {
  const cutoff = Date.now() - 24 * 60 * 60 * 1000;
  const rows = await env.DB.prepare(
    `SELECT id, object_key FROM photos
     WHERE deleted_at IS NOT NULL AND deleted_at <= ?
     LIMIT 50`,
  )
    .bind(cutoff)
    .all<{ id: string; object_key: string }>();
  let removed = 0;
  for (const row of rows.results ?? []) {
    await env.IMAGES.delete(row.object_key);
    removed += 1;
  }
  return removed;
}

/// Public host for gardener photos. The object key stays in Firestore.
const gardenImageHost = 'https://cloud-r2.raices.care';

/// Sent with every upload. Must match the value the signer includes in the URL.
const gardenImageCacheControl = 'public, max-age=300';

const gardenJpegContentType = 'image/jpeg';

/// Turns a stored object key into the custom-domain URL.
///
/// [version] is set after a replacement so a fixed key such as `avatar.jpg`
/// is not shown from the previous response.
String gardenImageUrl(String storagePath, {int? version}) {
  final url = '$gardenImageHost/$storagePath';
  if (version == null) {
    return url;
  }
  return '$url?v=$version';
}

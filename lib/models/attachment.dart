/// A document attached to an itinerary item. The actual file lives in the app
/// documents directory; [relativePath] is stored relative to that directory so
/// it survives app-container path changes between launches/reinstalls.
class Attachment {
  final String id;
  final String fileName; // original display name, e.g. "boarding-pass.pdf"
  final String relativePath; // e.g. "attachments/<id>.pdf"
  final String ext; // lowercase extension without dot, e.g. "pdf"

  const Attachment({
    required this.id,
    required this.fileName,
    required this.relativePath,
    required this.ext,
  });

  bool get isImage => const {'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'bmp'}.contains(ext);
  bool get isPdf => ext == 'pdf';

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'relativePath': relativePath,
        'ext': ext,
      };

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'] as String,
        fileName: (j['fileName'] ?? '') as String,
        relativePath: (j['relativePath'] ?? '') as String,
        ext: (j['ext'] ?? '') as String,
      );
}

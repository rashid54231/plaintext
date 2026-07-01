import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../config/supabase_config.dart';

class FilePickerService {
  static final FilePickerService instance = FilePickerService._();
  FilePickerService._();

  late final FilePicker _filePicker;
  bool _isInitialized = false;

  // ============================================
  // INITIALIZATION
  // ============================================

  Future<void> initialize() async {
    if (_isInitialized) return;
    _filePicker = FilePicker.platform;
    _isInitialized = true;
  }

  bool get isInitialized => _isInitialized;

  // ============================================
  // PICK FILES
  // ============================================

  Future<FilePickerResult?> pickFiles({
    bool allowMultiple = false,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      final result = await _filePicker.pickFiles(
        allowMultiple: allowMultiple,
        type: type,
        allowedExtensions: allowedExtensions,
      );
      return result;
    } catch (e) {
      throw Exception('Failed to pick files: $e');
    }
  }

  Future<FilePickerResult?> pickImages({bool allowMultiple = false}) async {
    return pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.image,
    );
  }

  Future<FilePickerResult?> pickDocuments({bool allowMultiple = false}) async {
    return pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'csv'],
    );
  }

  Future<FilePickerResult?> pickMedia({bool allowMultiple = false}) async {
    return pickFiles(
      allowMultiple: allowMultiple,
      type: FileType.media,
    );
  }

  // ============================================
  // UPLOAD TO SUPABASE
  // ============================================

  Future<String?> uploadFile({
    required String taskId,
    required PlatformFile file,
  }) async {
    if (file.path == null) return null;

    try {
      final filePath = file.path!;
      final fileName = file.name;
      final ext = p.extension(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'task-$taskId/$timestamp$ext';

      final supabase = SupabaseConfig.client;
      final fileObj = File(filePath);
      final bytes = await fileObj.readAsBytes();

      await supabase.storage
          .from('task-submissions')
          .uploadBinary(storagePath, bytes);

      final publicUrl = supabase.storage
          .from('task-submissions')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<String?> uploadFileBytes({
    required String taskId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final ext = p.extension(fileName);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'task-$taskId/$timestamp$ext';

      final supabase = SupabaseConfig.client;

      await supabase.storage
          .from('task-submissions')
          .uploadBinary(storagePath, bytes);

      final publicUrl = supabase.storage
          .from('task-submissions')
          .getPublicUrl(storagePath);

      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<List<String>> uploadMultipleFiles({
    required String taskId,
    required List<PlatformFile> files,
  }) async {
    final urls = <String>[];

    for (final file in files) {
      final url = await uploadFile(taskId: taskId, file: file);
      if (url != null) {
        urls.add(url);
      }
    }

    return urls;
  }

  // ============================================
  // FILE OPERATIONS
  // ============================================

  Future<List<String>> getTaskFiles(String taskId) async {
    try {
      final supabase = SupabaseConfig.client;
      final files = await supabase.storage
          .from('task-submissions')
          .list(path: 'task-$taskId');

      final urls = <String>[];
      for (final file in files) {
        final url = supabase.storage
            .from('task-submissions')
            .getPublicUrl('task-$taskId/${file.name}');
        urls.add(url);
      }
      return urls;
    } catch (e) {
      return [];
    }
  }

  Future<void> deleteFile(String taskId, String fileName) async {
    try {
      final supabase = SupabaseConfig.client;
      await supabase.storage
          .from('task-submissions')
          .remove(['task-$taskId/$fileName']);
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  Future<void> deleteTaskFiles(String taskId) async {
    try {
      final supabase = SupabaseConfig.client;
      final files = await supabase.storage
          .from('task-submissions')
          .list(path: 'task-$taskId');

      if (files.isNotEmpty) {
        final paths = files.map((f) => 'task-$taskId/${f.name}').toList();
        await supabase.storage
            .from('task-submissions')
            .remove(paths);
      }
    } catch (e) {
      // ignore
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  String getFileExtension(String fileName) {
    return p.extension(fileName).toLowerCase();
  }

  String getFileType(String fileName) {
    final ext = getFileExtension(fileName);
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.webp':
        return 'image';
      case '.pdf':
        return 'pdf';
      case '.doc':
      case '.docx':
        return 'document';
      case '.xls':
      case '.xlsx':
        return 'spreadsheet';
      case '.mp4':
      case '.avi':
      case '.mov':
        return 'video';
      case '.mp3':
      case '.wav':
        return 'audio';
      default:
        return 'file';
    }
  }

  bool isImageFile(String fileName) {
    return getFileType(fileName) == 'image';
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}

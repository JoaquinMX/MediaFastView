import 'sidecar_folder_data.dart';

/// Filesystem-resolution results for one mapped backup root.
class SidecarReadReport {
  const SidecarReadReport({
    this.folders = const <SidecarFolderData>[],
    this.failures = const <String>[],
  });

  final List<SidecarFolderData> folders;
  final List<String> failures;
}

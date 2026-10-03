import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/adb_service.dart';
import '../../core/logger.dart';

class FileManagerView extends StatefulWidget {
  final String deviceId;
  final AdbService adbService;
  final VoidCallback onClose;

  const FileManagerView({
    Key? key,
    required this.deviceId,
    required this.adbService,
    required this.onClose,
  }) : super(key: key);

  @override
  State<FileManagerView> createState() => _FileManagerViewState();
}

class _FileManagerViewState extends State<FileManagerView> {
  String _currentPath = '/sdcard';
  List<AdbFile> _files = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final files = await widget.adbService.listFiles(widget.deviceId, _currentPath);
    if (mounted) {
      setState(() {
        _files = files;
        _isLoading = false;
      });
    }
  }

  void _navigateUp() {
    if (_currentPath == '/') return;
    final parts = _currentPath.split('/');
    parts.removeLast();
    _currentPath = parts.isEmpty ? '/' : parts.join('/');
    if (_currentPath.isEmpty) _currentPath = '/';
    _loadFiles();
  }

  void _navigateTo(String name) {
    if (_currentPath == '/') {
      _currentPath = '/$name';
    } else {
      _currentPath = '$_currentPath/$name';
    }
    _loadFiles();
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    
    final localPath = result.files.single.path!;
    final fileName = result.files.single.name;
    final remotePath = '$_currentPath/$fileName'.replaceAll('//', '/');

    setState(() => _isLoading = true);
    AppLogger.log('[FileManager] Uploading $fileName...');
    final success = await widget.adbService.pushFile(widget.deviceId, localPath, remotePath);
    if (success) {
      AppLogger.log('[FileManager] Upload successful');
    } else {
      AppLogger.log('[FileManager] Upload failed');
    }
    await _loadFiles();
  }

  Future<void> _downloadFile(AdbFile file) async {
    final saveDir = await FilePicker.platform.getDirectoryPath();
    if (saveDir == null) return;

    final localPath = '$saveDir${Platform.pathSeparator}${file.name}';
    
    setState(() => _isLoading = true);
    AppLogger.log('[FileManager] Downloading ${file.name}...');
    final success = await widget.adbService.pullFile(widget.deviceId, file.path, localPath);
    if (success) {
      AppLogger.log('[FileManager] Download successful: $localPath');
    } else {
      AppLogger.log('[FileManager] Download failed');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteFile(AdbFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete ${file.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await widget.adbService.deleteFile(widget.deviceId, file.path);
      await _loadFiles();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 20),
                onPressed: widget.onClose,
                tooltip: 'Back to Mirror',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.drive_folder_upload, size: 20),
                      onPressed: _currentPath != '/' ? _navigateUp : null,
                      color: _currentPath != '/' ? Colors.blueAccent : Colors.grey,
                      tooltip: 'Up One Level',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Text(
                          _currentPath,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload'),
                onPressed: _isLoading ? null : _uploadFile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
        ),
        
        // Quick Access Shortcuts
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickLink(
                  icon: Icons.smartphone,
                  label: 'Internal',
                  path: '/sdcard',
                  currentPath: _currentPath,
                  onTap: () => setState(() { _currentPath = '/sdcard'; _loadFiles(); }),
                ),
                const SizedBox(width: 8),
                _QuickLink(
                  icon: Icons.image,
                  label: 'Gallery (DCIM)',
                  path: '/sdcard/DCIM',
                  currentPath: _currentPath,
                  onTap: () => setState(() { _currentPath = '/sdcard/DCIM'; _loadFiles(); }),
                ),
                const SizedBox(width: 8),
                _QuickLink(
                  icon: Icons.photo_library,
                  label: 'Pictures',
                  path: '/sdcard/Pictures',
                  currentPath: _currentPath,
                  onTap: () => setState(() { _currentPath = '/sdcard/Pictures'; _loadFiles(); }),
                ),
                const SizedBox(width: 8),
                _QuickLink(
                  icon: Icons.download,
                  label: 'Downloads',
                  path: '/sdcard/Download',
                  currentPath: _currentPath,
                  onTap: () => setState(() { _currentPath = '/sdcard/Download'; _loadFiles(); }),
                ),
                const SizedBox(width: 8),
                _QuickLink(
                  icon: Icons.music_note,
                  label: 'Music',
                  path: '/sdcard/Music',
                  currentPath: _currentPath,
                  onTap: () => setState(() { _currentPath = '/sdcard/Music'; _loadFiles(); }),
                ),
                const SizedBox(width: 8),
                _QuickLink(
                  icon: Icons.movie,
                  label: 'Movies',
                  path: '/sdcard/Movies',
                  currentPath: _currentPath,
                  onTap: () => setState(() { _currentPath = '/sdcard/Movies'; _loadFiles(); }),
                ),
              ],
            ),
          ),
        ),

        // File List
        Expanded(
          child: _isLoading && _files.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  itemCount: _files.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    return ListTile(
                      leading: Icon(
                        file.isDirectory ? Icons.folder : Icons.insert_drive_file,
                        color: file.isDirectory ? Colors.amber : Colors.white70,
                      ),
                      title: Text(file.name, style: const TextStyle(fontSize: 14)),
                      subtitle: file.isDirectory 
                        ? null 
                        : Text('${_formatSize(file.size)} • ${file.modifiedAt.toString().split('.')[0]}', 
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5))),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!file.isDirectory)
                            IconButton(
                              icon: const Icon(Icons.download, size: 20),
                              onPressed: () => _downloadFile(file),
                              tooltip: 'Download to PC',
                              color: Colors.greenAccent,
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: () => _deleteFile(file),
                            tooltip: 'Delete',
                            color: Colors.redAccent,
                          ),
                        ],
                      ),
                      onTap: file.isDirectory ? () => _navigateTo(file.name) : null,
                    );
                  },
                ),
        ),
        
        // Loading Overlay
        if (_isLoading && _files.isNotEmpty)
          const LinearProgressIndicator(),
      ],
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final String path;
  final String currentPath;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.path,
    required this.currentPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentPath == path;
    return ActionChip(
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white70),
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12)),
      backgroundColor: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.05),
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}

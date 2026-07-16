import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/message.dart';
import '../logic/chat_cubit.dart';
import '../logic/chat_state.dart';

class FilePreviewPage extends StatelessWidget {
  const FilePreviewPage({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final extra = message.fileExtra;
    return Scaffold(
      appBar: AppBar(title: const Text('文件详情')),
      body: BlocBuilder<ChatCubit, ChatState>(
        builder: (context, state) {
          final info = state is ChatLoaded
              ? state.fileDownloads[message.id]
              : null;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.insert_drive_file,
                    size: 72,
                    color: Color(0xFF5B6B82),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    extra?.fileName ?? message.content,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${extra?.formattedSize ?? '0 B'} · ${extra?.fileType.toUpperCase() ?? ''}',
                  ),
                  const SizedBox(height: 24),
                  if (info?.status == FileDownloadStatus.downloading) ...[
                    LinearProgressIndicator(value: info!.progress),
                    const SizedBox(height: 8),
                    Text('${(info.progress * 100).round()}%'),
                  ] else if (info?.status == FileDownloadStatus.done) ...[
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(height: 8),
                    Text(info?.localPath ?? '', textAlign: TextAlign.center),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: extra == null || extra.fileUrl.isEmpty
                          ? null
                          : () => context.read<ChatCubit>().downloadFile(
                              message.id,
                              extra.fileUrl,
                              extra.fileName,
                            ),
                      icon: const Icon(Icons.download),
                      label: Text(
                        info?.status == FileDownloadStatus.error
                            ? '重试下载'
                            : '下载文件',
                      ),
                    ),
                    if (info?.status == FileDownloadStatus.error) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '下载失败，请重试',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

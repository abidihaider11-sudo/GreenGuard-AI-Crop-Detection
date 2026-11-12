import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/scan_history_service.dart';
import '../data/disease_data.dart';
import '../widgets/gg_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanRecord> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final records = await ScanHistoryService.loadHistory();
    if (mounted) {
      setState(() {
        _history = records;
        _loading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to delete all scan history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ScanHistoryService.clearHistory();
      await _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Scan History', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear History',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history_rounded, size: 72, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text(
                        'No scans yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your last 10 scans will appear here',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: _history.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      final bool isHealthy = item.diseaseDetected.toLowerCase().contains('healthy');
                      final bool isUnknown = item.diseaseDetected == 'Unknown';
                      final Color statusColor = isUnknown
                          ? Colors.grey
                          : isHealthy
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFD32F2F);

                      return GGCard(
                        padding: EdgeInsets.zero,
                        onTap: () {
                          // Note: In a full app, we'd navigate back to ResultScreen with this data
                        },
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              // Image Thumbnail
                              ClipRRect(
                                borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  color: colorScheme.surfaceVariant,
                                  child: item.imagePath != null
                                      ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
                                      : Center(child: Icon(Icons.image_not_supported_outlined, size: 32, color: colorScheme.onSurface.withValues(alpha: 0.2))),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        DiseaseData.getInfo(item.diseaseDetected).formattedName,
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: colorScheme.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${(item.confidence * 100).toStringAsFixed(1)}% Conf.',
                                              style: GoogleFonts.poppins(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat('MMM d, HH:mm').format(item.scannedAt),
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: colorScheme.onSurface.withValues(alpha: 0.4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colorScheme.onSurface.withValues(alpha: 0.2),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

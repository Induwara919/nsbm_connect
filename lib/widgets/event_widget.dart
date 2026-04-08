import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Added
import '../theme.dart';

class EventWidget extends StatefulWidget {
  final Map<String, dynamic> event;
  final String heroContext;

  const EventWidget({
    super.key,
    required this.event,
    this.heroContext = 'event'
  });

  @override
  State<EventWidget> createState() => _EventWidgetState();

  static Widget buildEventList(Stream<List<Map<String, dynamic>>> stream, {
    String emptyMessage = "No events scheduled.",
    String contextPrefix = 'list'
  }) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15)
                ),
                child: Text(
                  emptyMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w500
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        }

        return Column(
          children: events.map((event) => EventWidget(
              event: event,
              heroContext: contextPrefix
          )).toList(),
        );
      },
    );
  }
}

class _EventWidgetState extends State<EventWidget> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final String imageUrl = widget.event['image']?.toString() ?? '';
    final String uniqueHeroTag = "${widget.heroContext}_${identityHashCode(widget.event)}_$imageUrl";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (imageUrl.isNotEmpty) {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => FullScreenImage(
                          imageUrl: imageUrl,
                          heroTag: uniqueHeroTag,
                        ),
                      ));
                    }
                  },
                  child: Hero(
                    tag: uniqueHeroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: (imageUrl.isNotEmpty)
                          ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 110,
                        height: 110,
                        memCacheHeight: 300, // Optimizes RAM
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) => _placeholder(),
                      )
                          : _placeholder(),
                    ),
                  ),
                ),
                const SizedBox(width: 15),

                Expanded(
                  child: SizedBox(
                    height: 108,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.event['title'] ?? '',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        _infoRow(Icons.calendar_month_rounded, Colors.orange, widget.event['date'] ?? ''),
                        _infoRow(Icons.access_time_rounded, Colors.blue, "${widget.event['start_time']} - ${widget.event['end_time']}"),
                        _infoRow(Icons.location_on_rounded, Colors.redAccent, widget.event['location'] ?? ''),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),
            const Divider(height: 1),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final text = widget.event['description'] ?? '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      maxLines: isExpanded ? 100 : 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                    ),
                    if (text.length > 150)
                      GestureDetector(
                        onTap: () => setState(() => isExpanded = !isExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            isExpanded ? "Read Less" : "Read More",
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
        width: 110,
        height: 110,
        color: Colors.grey[200],
        child: const Icon(Icons.image, color: Colors.grey)
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const FullScreenImage({super.key, required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorWidget: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white, size: 50),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:chess_srs/src/model/blog/blog.dart';
import 'package:chess_srs/src/network/aggregator.dart';
import 'package:chess_srs/src/network/http.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final blogCarouselProvider = FutureProvider.autoDispose<IList<BlogPost>>((ref) {
  return ref.read(blogRepositoryProvider).getCarousel();
}, name: 'BlogCarouselProvider');

final blogRepositoryProvider = Provider<BlogRepository>((ref) {
  final client = ref.watch(lichessClientProvider);
  final aggregator = ref.watch(aggregatorProvider);
  return BlogRepository(client, aggregator);
}, name: 'BlogRepositoryProvider');

class BlogRepository {
  BlogRepository(this.client, this.aggregator);

  final LichessClient client;
  final Aggregator aggregator;

  Future<IList<BlogPost>> getCarousel() {
    return client.readJsonList(Uri(path: '/api/blog/carousel'), mapper: BlogPost.fromServerJson);
  }
}

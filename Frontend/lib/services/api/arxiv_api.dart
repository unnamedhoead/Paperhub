import '../core/http_client.dart';
import '../arxiv_service.dart';

/// arXiv API — delegates metadata fetching to [ArxivService].
///
/// The ArxivService talks directly to the backend arXiv proxy endpoint
/// (via `http` package), so this class exists to give the arxiv domain a
/// consistent entry point in `services/api/` alongside post_api, etc.
class ArxivApi {
  /// Fetch arXiv metadata from an ID or URL.
  /// Delegates to [ArxivService.fetchMetadata].
  static Future<ArxivMetadata> fetchMetadata(String input) {
    return ArxivService.fetchMetadata(input);
  }

  /// Extract arXiv ID from a raw input string.
  static String? extractArxivId(String input) {
    return ArxivService.extractArxivId(input);
  }
}

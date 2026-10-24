import '../endpoint/contract_envelope.dart';
import '../endpoint/endpoint_client.dart';
import 'catalogue.dart';

/// The catalogue document, wherever its bytes come from: the endpoint, or a saved copy.
const _kind = 'catalogue';

extension CatalogueDocument on EndpointClient {
  Future<DocumentOutcome<Catalogue>> fetchCatalogue() =>
      fetchDocument('/v1/catalogue', kind: _kind, parse: Catalogue.parse);
}

DocumentOutcome<Catalogue> openCatalogue(String body) =>
    openDocument(body, kind: _kind, parse: Catalogue.parse);

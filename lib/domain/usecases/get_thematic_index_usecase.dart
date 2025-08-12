import '../repositories/thematic_index_repository.dart';

class GetThematicIndexUseCase {
  final ThematicIndexRepository _repository;

  GetThematicIndexUseCase(this._repository);

  Future<Map<String, dynamic>> call() async {
    return await _repository.getThematicIndex();
  }
}

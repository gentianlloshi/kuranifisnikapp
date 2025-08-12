import 'package:kurani_fisnik_app/domain/repositories/storage_repository.dart';

class AddVerseToMemorizationUseCase {
  final StorageRepository repository;

  AddVerseToMemorizationUseCase(this.repository);

  Future<void> execute(String verseKey) async {
    await repository.addVerseToMemorization(verseKey);
  }
}

class RemoveVerseFromMemorizationUseCase {
  final StorageRepository repository;

  RemoveVerseFromMemorizationUseCase(this.repository);

  Future<void> execute(String verseKey) async {
    await repository.removeVerseFromMemorization(verseKey);
  }
}

class GetMemorizationListUseCase {
  final StorageRepository repository;

  GetMemorizationListUseCase(this.repository);

  Future<List<String>> execute() async {
    return await repository.getMemorizationList();
  }
}

class IsVerseMemorizedUseCase {
  final StorageRepository repository;

  IsVerseMemorizedUseCase(this.repository);

  Future<bool> execute(String verseKey) async {
    return await repository.isVerseMemorized(verseKey);
  }
}



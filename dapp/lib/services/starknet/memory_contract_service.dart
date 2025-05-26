import 'package:starknet_provider/starknet_provider.dart';
import 'package:starknet/starknet.dart' show Felt;
import '../../config/starknet_config.dart';
import '../../utils/starknet_utils.dart';

class MemoryContractService {
  final JsonRpcProvider provider;

  MemoryContractService({
    required this.provider,
  });

Future<List<Memory>> getMemoriesByOwner(String ownerAddress) async {
  try {
    Felt selector;
    try {
      selector = await StarknetUtils.getFunctionSelector(
        provider,
        StarknetConfig.contractAddress,
        'get_records_by_owner',
      );
    } catch (e) {
      selector = Felt.fromHexString('0x1a8cfea6d1a66dfceba35b10f5a3cfebbfe033702a6713ff0af802f86667b3e');
    }

    final result = await provider.call(
      request: FunctionCall(
        contractAddress: Felt.fromHexString(StarknetConfig.contractAddress),
        entryPointSelector: selector,
        calldata: [Felt.fromHexString(ownerAddress)],
      ),
      blockId: BlockId.latest,
    );

    return result.when(
      result: (data) {
        if (data == null || data is! List || data.length < 2) return <Memory>[];
        final flat = data.cast<Felt>();
        print('flat data: $flat');

        final records = StarknetUtils.parseContractRecords(flat);
        final memories = records.map((record) => Memory(
          id: record.hashCommit,
          title: record.name,
          content: 'https://ipfs.io/ipfs/${record.cid}',
          imageUrl: '',
          createdAt: record.timestamp,
          accessType: record.accessType,
        )).toList();

        return memories;
      },
      error: (error) {
        print('❌ Error al llamar el contrato: $error');
        return <Memory>[];
      },
    );
  } catch (e, stack) {
    print('❌ Error general: $e');
    print(stack);
    return [];
  }
}

}


// Modelo para representar una memoria
class Memory {
  final String id;
  final String title;
  final String content;
  final String imageUrl;
  final DateTime createdAt;
  final String accessType;

  Memory({
    required this.id,
    required this.title,
    required this.content,
    required this.imageUrl,
    required this.createdAt,
    required this.accessType,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'imageUrl': imageUrl,
    'createdAt': createdAt.toIso8601String(),
    'accessType': accessType,
  };

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    imageUrl: json['imageUrl'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    accessType: json['accessType'] as String,
  );
} 
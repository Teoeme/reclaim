import 'package:flutter/material.dart';
import '../services/starknet/memory_contract_service.dart';
import '/flutter_flow/nav/nav.dart';
import '/pages/unlock_memory/unlock_memory_widget.dart';


class MemoryList extends StatefulWidget {
  final MemoryContractService memoryService;
  final String ownerAddress;

  const MemoryList({
    Key? key,
    required this.memoryService,
    required this.ownerAddress,
  }) : super(key: key);

  @override
  State<MemoryList> createState() => _MemoryListState();
}

class _MemoryListState extends State<MemoryList> {
  List<Memory> _memories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('🔄 Iniciando carga de memorias para: ${widget.ownerAddress}');
      final memories = await widget.memoryService.getMemoriesByOwner(widget.ownerAddress);
      print('✅ Memorias cargadas: ${memories.length}');
      
      setState(() {
        _memories = memories;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('❌ Error al cargar memorias: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _error = 'Error al cargar las memorias: $e';
        _isLoading = false;
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            ElevatedButton(
              onPressed: _loadMemories,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_memories.isEmpty) {
      return const Center(
        child: Text('No hay memorias disponibles'),
      );
    }

    return ListView.builder(
      itemCount: _memories.length,
      itemBuilder: (context, index) {
        final memory = _memories[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: memory.imageUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      memory.imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.image),
            title: Text(memory.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  memory.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Tipo de acceso: ${memory.accessType}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${memory.createdAt.toString().split('.')[0]}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (memory.accessType == 'timestamp' && 
                    DateTime.now().millisecondsSinceEpoch >= memory.createdAt.millisecondsSinceEpoch)
                  TextButton(
                    onPressed: () {
                      context.pushNamed(
                        UnlockMemoryWidget.routeName,
                        extra: memory.toJson(),
                      );
                    },
                    child: Text(
                      'Desbloquear',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
} 
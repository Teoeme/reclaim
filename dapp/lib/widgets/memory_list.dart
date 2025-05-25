import 'package:flutter/material.dart';
import '../services/starknet/memory_contract_service.dart';

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

      final memories = await widget.memoryService.getMemoriesByOwner(widget.ownerAddress);
      
      setState(() {
        _memories = memories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar las memorias: $e';
        _isLoading = false;
      });
    }
  }

  String _getAccessTypeText(int accessType) {
    switch (accessType) {
      case 0:
        return 'Público';
      case 1:
        return 'Privado';
      default:
        return 'Desconocido';
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
                  'Tipo de acceso: ${_getAccessTypeText(memory.accessType)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            trailing: Text(
              memory.createdAt.toString().split(' ')[0],
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      },
    );
  }
} 
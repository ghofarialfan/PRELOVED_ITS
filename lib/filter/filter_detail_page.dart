// lib/filter/filter_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../search_page.dart'; 
import 'package:preloved_its/models/filter_data.dart';

enum FilterType { checklist, priceInput, singleSelection }

class FilterDetailPage extends StatefulWidget {
  final String title;
  final List<String>? options;
  final List<String> initialSelected;
  final FilterData currentFilter;

  const FilterDetailPage({
    super.key,
    required this.title,
    required this.currentFilter,
    this.options,
    this.initialSelected = const [],
  });

  @override
  State<FilterDetailPage> createState() => _FilterDetailPageState();
}

class _FilterDetailPageState extends State<FilterDetailPage> {
  late List<String> _selectedOptions;
  late TextEditingController _minController;
  late TextEditingController _maxController;
  FilterType _filterType = FilterType.checklist;

  @override
  void initState() {
    super.initState();
    _selectedOptions = List.from(widget.initialSelected);
    if (widget.title == 'Harga') {//Penentuan Tipe Filter (initState)
      _filterType = FilterType.priceInput;
      _minController = TextEditingController(text: widget.currentFilter.minPrice == 0 ? '' : widget.currentFilter.minPrice.toString());
      _maxController = TextEditingController(text: widget.currentFilter.maxPrice == 100000000 ? '' : widget.currentFilter.maxPrice.toString());
    } else if (widget.title == 'Sort By') {
      _filterType = FilterType.singleSelection;
    } else {
      _filterType = FilterType.checklist;
    }
  }

  @override
  void dispose() {
    if (_filterType == FilterType.priceInput) {
      _minController.dispose();
      _maxController.dispose();
    }
    super.dispose();
  }

  void _handleOptionTap(String option) { //Logika Pilihan (_handleOptionTap)
    setState(() { 
      if (widget.title == 'Sort By') {
        if (_selectedOptions.contains(option)) {
          _selectedOptions.clear();
        } else {
          _selectedOptions = [option];
        }
      } else {
        if (_selectedOptions.contains(option)) {
          _selectedOptions.remove(option);
        } else {
          _selectedOptions.add(option);
        }
      }
    });
  }

  void _resetFilter() { //fitur reset
    setState(() {
      if (_filterType == FilterType.priceInput) {
        _minController.clear();
        _maxController.clear();
      } else {
        _selectedOptions.clear();
      }
    });
  }

  Color _getColorFromName(String name) {
    switch (name) {
      case 'Hitam': return Colors.black;
      case 'Putih': return Colors.white;
      case 'Abu-abu': return Colors.grey;
      case 'Coklat': return Colors.brown;
      case 'Kuning': return Colors.yellow;
      case 'Merah': return Colors.red;
      case 'Biru': return Colors.blue;
      case 'Hijau': return Colors.green;
      case 'Oren': return Colors.orange;
      case 'Ungu': return Colors.purple;
      case 'Pink': return Colors.pink;
      default: return Colors.transparent;
    }
  }

  Widget _buildChecklist() {
    return ListView.separated(
      itemCount: widget.options!.length,
      separatorBuilder: (context, index) => const Divider(height: 1), 
      itemBuilder: (context, index) {
        final option = widget.options![index];
        final isSelected = _selectedOptions.contains(option);
        return ListTile(
          onTap: () => _handleOptionTap(option),
          leading: widget.title == 'Warna'
              ? Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _getColorFromName(option),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                )
              : null,
          title: Text(option, style: const TextStyle(fontSize: 16)),
          // Wadah Kotak Centang di pojok kanan
          trailing: Checkbox(
            value: isSelected,
            activeColor: primaryBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), 
            onChanged: (bool? value) => _handleOptionTap(option),
          ),
        );
      },
    );
  }

  Widget _buildPriceInput() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Dari', style: TextStyle(color: Colors.black54)),
                TextField(
                  controller: _minController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    hintText: 'Min',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sampai', style: TextStyle(color: Colors.black54)),
                TextField(
                  controller: _maxController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixText: 'Rp ',
                    hintText: 'Max',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true, 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context), //Pengembalian Data
        ),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
            child: OutlinedButton( 
              onPressed: _resetFilter,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBlue,
                side: const BorderSide(color: primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('Riset'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1), 
          Expanded(
            child: _filterType == FilterType.priceInput 
                ? _buildPriceInput() 
                : _buildChecklist(),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_filterType == FilterType.priceInput) {
                  final minPrice = int.tryParse(_minController.text) ?? 0;
                  final maxPrice = int.tryParse(_maxController.text) ?? 100000000;
                  Navigator.pop(context, {'min': minPrice, 'max': maxPrice});
                } else {
                  Navigator.pop(context, _selectedOptions);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Show Results', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
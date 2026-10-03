import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../models/job_expense.dart';
import '../../models/tools/tool_photo.dart';
import '../tools/pickers/photos_picker_screen.dart';

const _brand = Color(0xFFF64C13);
const _pageBg = Color(0xFFF5F5F7);

/// Add/edit one expense row on a Job. Returns the [JobExpense] back to
/// the caller via Navigator.pop — caller is responsible for splicing
/// it into the job's expense list.
class ExpenseEditScreen extends StatefulWidget {
  const ExpenseEditScreen({super.key, this.existing});
  final JobExpense? existing;

  @override
  State<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends State<ExpenseEditScreen> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late DateTime _date;
  ToolPhoto? _receipt;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e.title;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      _descCtrl.text = e.description;
      _date = e.date;
      _receipt = e.receipt;
    } else {
      _date = DateTime.now();
    }
    _titleCtrl.addListener(() => setState(() {}));
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canSave {
    final t = _titleCtrl.text.trim();
    final a = double.tryParse(_amountCtrl.text.trim());
    return t.isNotEmpty && a != null && a > 0;
  }

  Future<void> _pickDate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickReceipt() async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Reuses the existing Photos tool picker (and its embedded
    // upload screen via the "+" action) so a tradesman can attach a
    // brand-new receipt without leaving the expense form.
    final picked = await Navigator.of(context).push<List<ToolPhoto>>(
      MaterialPageRoute(
        builder: (_) => PhotosPickerScreen(
          singleSelect: true,
          title: 'Pick a receipt',
          initialSelectedIds:
              _receipt == null ? const {} : {_receipt!.id},
        ),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    setState(() => _receipt = picked.first);
  }

  void _clearReceipt() {
    setState(() => _receipt = null);
  }

  void _save() {
    if (!_canSave) return;
    final id = widget.existing?.id ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final out = JobExpense(
      id: id,
      title: _titleCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text.trim()),
      date: _date,
      description: _descCtrl.text.trim(),
      receipt: _receipt,
    );
    Navigator.of(context).pop(out);
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.existing == null ? 'New expense' : 'Edit expense'),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: _canSave ? _brand : Colors.grey.shade400,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          children: [
            _Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                child: Column(
                  children: [
                    _Field(
                      label: 'Expense name',
                      child: TextField(
                        controller: _titleCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'e.g. Materials, fuel, parking',
                          hintStyle: TextStyle(
                            color: Colors.black.withValues(alpha: 0.28),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _Field(
                      label: 'Amount',
                      child: TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          prefixText: '£ ',
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: Colors.black.withValues(alpha: 0.28),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    InkWell(
                      onTap: _pickDate,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _fmtDate(_date),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 18,
                              color: Colors.grey.shade400,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    _Field(
                      label: 'Description',
                      child: TextField(
                        controller: _descCtrl,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        minLines: 2,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Optional',
                          hintStyle: TextStyle(
                            color: Colors.black.withValues(alpha: 0.28),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _ReceiptCard(
              receipt: _receipt,
              onPick: _pickReceipt,
              onClear: _clearReceipt,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({
    required this.receipt,
    required this.onPick,
    required this.onClear,
  });

  final ToolPhoto? receipt;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.receipt, size: 18, color: _brand),
              const SizedBox(width: 8),
              const Text(
                'Receipt',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (receipt == null)
                TextButton.icon(
                  onPressed: onPick,
                  icon: const Icon(
                    LucideIcons.plus,
                    size: 16,
                    color: _brand,
                  ),
                  label: const Text(
                    'Add',
                    style: TextStyle(
                      color: _brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: onPick,
                  icon: Icon(
                    LucideIcons.repeat,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  label: Text(
                    'Change',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
          if (receipt == null) ...[
            const SizedBox(height: 8),
            Text(
              'Attach a photo of the receipt — picks from your Photos tool.',
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: receipt!.url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        color: Colors.grey.shade200,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: Icon(
                          LucideIcons.imageOff,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onClear,
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              LucideIcons.x,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (receipt!.title.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                receipt!.title,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

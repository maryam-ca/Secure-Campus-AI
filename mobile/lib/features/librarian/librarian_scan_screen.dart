import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/issue_search.dart';
import '../../core/utils/student_search.dart';
import '../../core/widgets/animated_shield_logo.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../models/admin_models.dart';
import '../library/book_lock_ui.dart';
import '../../models/student_model.dart';
import '../../providers/librarian_providers.dart';

/// Four L-shaped corner brackets with a slow up-down "breathing" glow
/// line between them - the standard, recognizable visual language of a
/// live scanner (not decoration for its own sake: it directly shows the
/// camera is actively looking for a code).
class _ScannerFrame extends StatefulWidget {
  const _ScannerFrame();

  @override
  State<_ScannerFrame> createState() => _ScannerFrameState();
}

class _ScannerFrameState extends State<_ScannerFrame> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _corner({required bool top, required bool left}) {
    return Positioned(
      top: top ? 0 : null,
      bottom: top ? null : 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            bottom: !top ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            left: left ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
            right: !left ? const BorderSide(color: Colors.white, width: 4) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(10) : Radius.zero,
            topRight: top && !left ? const Radius.circular(10) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(10) : Radius.zero,
            bottomRight: !top && !left ? const Radius.circular(10) : Radius.zero,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 240,
      child: Stack(
        children: [
          _corner(top: true, left: true),
          _corner(top: true, left: false),
          _corner(top: false, left: true),
          _corner(top: false, left: false),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Positioned(
              top: 14 + _controller.value * 212,
              left: 14,
              right: 14,
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: AppColors.accentLightBlue.withValues(alpha: 0.9), blurRadius: 8, spreadRadius: 1)],
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LibrarianScanScreen extends ConsumerStatefulWidget {
  const LibrarianScanScreen({super.key});

  @override
  ConsumerState<LibrarianScanScreen> createState() => _LibrarianScanScreenState();
}

class _LibrarianScanScreenState extends ConsumerState<LibrarianScanScreen> {
  final MobileScannerController _controller = MobileScannerController();
  final _manualIdController = TextEditingController();
  bool _scanning = false;
  bool _handling = false;
  String? _lastError;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    await _lookupBook(code);
  }

  /// Stops the camera as soon as a code has been read, so it is not left
  /// running (and decoding) behind the book sheet. Safe to call when the
  /// camera is not running (manual ID entry).
  Future<void> _pauseCamera() async {
    try {
      await _controller.stop();
    } catch (_) {
      // already stopped / never started
    }
  }

  Future<void> _resumeCamera() async {
    try {
      await _controller.start();
    } catch (_) {
      // the camera view will start it itself when it is shown again
    }
  }

  Future<void> _lookupBook(String code) async {
    setState(() {
      _handling = true;
      _lastError = null;
    });
    await _pauseCamera();

    final book = await ref.read(librarianRepositoryProvider).fetchBookById(code);
    if (!mounted) return;

    if (book == null) {
      setState(() {
        _handling = false;
        _lastError = 'No book found for code "$code".';
      });
      // Not one of our books: keep scanning so another code can be tried.
      if (_scanning) await _resumeCamera();
      return;
    }

    // A book that is already issued: offer to return it right here. Scanning
    // the book itself is the proof that the right book is in hand.
    LibrarianIssueRow? openLoan;
    if (!book.available) {
      try {
        openLoan = await ref.read(librarianRepositoryProvider).fetchActiveIssueForBook(book.id);
      } catch (_) {
        openLoan = null; // fall back to the normal sheet (shows "issued elsewhere")
      }
      if (!mounted) return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: AppColors.cardBackground,
      builder: (_) => book.locked
          ? _BookLockedSheet(book: book)
          : openLoan != null
              ? _BookReturnSheet(issue: openLoan)
              : _BookIssueSheet(book: book),
    );

    if (mounted) setState(() {
      _handling = false;
      _scanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_scanning,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _scanning) {
          setState(() {
            _scanning = false;
            _lastError = null;
          });
        }
      },
      child: _scanning ? _buildCameraView() : _buildIdleView(),
    );
  }

  Widget _buildIdleView() {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AnimatedShieldLogo(size: 72),
          const SizedBox(height: 18),
          Text('Issue or Return a book', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'Scan a book\'s QR code, or type its Book ID below. An available book is issued; an issued book is returned.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.bodyText),
          ),
          const SizedBox(height: 28),
          PressableScale(
            onTap: () => setState(() {
              _scanning = true;
              _lastError = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Scan QR Code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualIdController,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Or type a Book ID (e.g. BOOK-001)',
                    prefixIcon: const Icon(Icons.menu_book_outlined, size: 20),
                    filled: true,
                    fillColor: AppColors.accentLightBlue.withValues(alpha: 0.35),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) _lookupBook(v.trim());
                  },
                ),
              ),
              const SizedBox(width: 10),
              PressableScale(
                onTap: _handling
                    ? null
                    : () {
                        final v = _manualIdController.text.trim();
                        if (v.isNotEmpty) _lookupBook(v);
                      },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: _handling
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search, color: Colors.white),
                ),
              ),
            ],
          ),
          if (_lastError != null) ...[
            const SizedBox(height: 14),
            Text(_lastError!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(controller: _controller, onDetect: _onDetect),
        IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.85,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
                stops: const [0.55, 1.0],
              ),
            ),
          ),
        ),
        const Center(child: _ScannerFrame()),
        Positioned(
          top: 16,
          left: 16,
          child: PressableScale(
            onTap: () => setState(() {
              _scanning = false;
              _lastError = null;
            }),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ),
        if (_handling)
          Container(
            color: Colors.black54,
            child: const Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualIdController.dispose();
    super.dispose();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _BookIssueSheet extends ConsumerStatefulWidget {
  final BookModel book;
  const _BookIssueSheet({required this.book});

  @override
  ConsumerState<_BookIssueSheet> createState() => _BookIssueSheetState();
}

class _BookIssueSheetState extends ConsumerState<_BookIssueSheet> {
  final _regNoController = TextEditingController();
  List<StudentModel> _allStudents = const [];
  List<StudentModel> _matches = const [];
  StudentModel? _foundStudent;
  bool _searching = true; // true while the student list is loading
  bool _submitting = false;
  String? _error;

  DateTime _dueDate = DateTime.now().add(const Duration(days: 14));

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _regNoController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final students = await ref.read(librarianRepositoryProvider).fetchAllStudents();
      if (!mounted) return;
      setState(() {
        _allStudents = students;
        _searching = false;
      });
      _onQueryChanged(_regNoController.text);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = 'Could not load students: $e';
      });
    }
  }

  /// Runs on every keystroke. Typing 2+ characters lists every student whose
  /// registration number OR name contains them ("00", "007", "ayesh"). The
  /// librarian checks the name and complete ID and taps the right student;
  /// nothing is selected automatically, and editing the text clears any
  /// earlier selection.
  void _onQueryChanged(String text) {
    final q = text.trim();
    final matches = searchStudents(_allStudents, q);
    final searched = q.length >= studentSearchMinChars;
    setState(() {
      _matches = matches;
      _foundStudent = null;
      _error = (searched && matches.isEmpty && !_searching) ? 'No student found matching "$q".' : null;
    });
  }

  void _pickStudent(StudentModel s) {
    setState(() {
      _foundStudent = s;
      _matches = [s];
      _regNoController.text = s.registrationNumber;
      _regNoController.selection = TextSelection.collapsed(offset: _regNoController.text.length);
    });
  }

  Future<void> _pickDueDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year, pickedDate.month, pickedDate.day,
      pickedTime.hour, pickedTime.minute,
    );

    if (combined.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due date/time must be in the future.')),
      );
      return;
    }

    setState(() => _dueDate = combined);
  }

  Future<void> _issue() async {
    if (_foundStudent == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      await ref.read(librarianRepositoryProvider).issueBook(
            book: widget.book,
            student: _foundStudent!,
            issueDate: now,
            expiryDate: _dueDate,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'Could not issue book: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _dateChip({required IconData icon, required String label, required VoidCallback onTap}) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.accentLightBlue.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: AppColors.primaryBlueDark),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: AppColors.primaryBlueDark, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    return Padding(
      padding: EdgeInsets.only(left: 22, right: 22, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(4)),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.accentLightBlue, shape: BoxShape.circle),
                child: const Icon(Icons.menu_book_outlined, color: AppColors.primaryBlueDark, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(book.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text('${book.id} · ${book.author}', style: const TextStyle(color: AppColors.bodyText)),
                  ],
                ),
              ),
            ],
          ),
          if (!book.available) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
              child: const Text('This book is currently marked as ISSUED elsewhere.',
                  style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _regNoController,
            decoration: const InputDecoration(
              labelText: 'Student ID or name',
              helperText: 'Type part of the ID (e.g. 00) or the name (e.g. ayesh), then tap the student',
              helperMaxLines: 2,
              prefixIcon: Icon(Icons.badge_outlined),
              suffixIcon: Icon(Icons.search),
            ),
            onChanged: _onQueryChanged,
          ),
          if (_searching) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
          if (_foundStudent == null && _matches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                '${_matches.length} student${_matches.length == 1 ? '' : 's'} found - check the name and ID, then tap one',
                style: const TextStyle(color: AppColors.bodyText, fontSize: 12.5),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in _matches)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.person_outline),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.registrationNumber} · ${s.program}, Sem ${s.semester}'),
                      onTap: () => _pickStudent(s),
                    ),
                ],
              ),
            ),
          ],
          if (_foundStudent != null)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(opacity: t.clamp(0, 1), child: Transform.scale(scale: 0.9 + 0.1 * t, child: child)),
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_foundStudent!.name} (${_foundStudent!.registrationNumber}) — ${_foundStudent!.program}, Sem ${_foundStudent!.semester}',
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _dateChip(
                  icon: Icons.event_outlined,
                  label: 'Issue: ${DateFormat('dd MMM, HH:mm').format(DateTime.now())}',
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Issue date/time is set automatically when you tap "Issue Book".')),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _dateChip(
                  icon: Icons.event_busy_outlined,
                  label: 'Due: ${DateFormat('dd MMM, HH:mm').format(_dueDate)}',
                  onTap: _pickDueDate,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          PressableScale(
            onTap: (_foundStudent == null || _submitting || !book.available) ? null : _issue,
            child: Container(
              width: double.infinity,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (_foundStudent == null || _submitting || !book.available)
                    ? AppColors.divider
                    : AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(14),
                boxShadow: (_foundStudent == null || _submitting || !book.available)
                    ? []
                    : [BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : Text(
                      'Issue Book',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: (_foundStudent == null || !book.available) ? AppColors.bodyText : Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the scanned book is already issued: who has it, when it is due,
/// and a Return button. The scan itself confirmed it is the right book.
class _BookReturnSheet extends ConsumerStatefulWidget {
  final LibrarianIssueRow issue;
  const _BookReturnSheet({required this.issue});

  @override
  ConsumerState<_BookReturnSheet> createState() => _BookReturnSheetState();
}

class _BookReturnSheetState extends ConsumerState<_BookReturnSheet> {
  bool _returning = false;
  String? _error;

  Future<void> _return() async {
    setState(() {
      _returning = true;
      _error = null;
    });
    try {
      await ref.read(librarianRepositoryProvider).returnBook(widget.issue, method: ReturnMethod.scan);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Returned "${widget.issue.bookTitle}" from ${widget.issue.studentName}.'),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not return the book: $e');
    } finally {
      if (mounted) setState(() => _returning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final overdue = issue.isOverdue;
    final fmt = DateFormat('dd MMM yyyy');

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 18, 22, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This book is currently issued',
              style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(issue.bookTitle, style: Theme.of(context).textTheme.titleLarge),
          Text(issue.bookId, style: const TextStyle(color: AppColors.bodyText)),
          const SizedBox(height: 14),
          Text('Issued to ${issue.studentName} (${issue.registrationNumber})',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            'Issued ${fmt.format(issue.issueDate)} · Due ${fmt.format(issue.expiryDate)}${overdue ? ' · OVERDUE' : ''}',
            style: TextStyle(color: overdue ? AppColors.error : AppColors.bodyText, fontWeight: overdue ? FontWeight.w700 : null),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _returning ? null : _return,
              icon: _returning
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.assignment_return_outlined),
              label: const Text('Return this book'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the scanned book is locked (kept in the safe): it cannot be
/// issued. Shows why, who locked it and when, and lets the librarian unlock
/// it (with a reason, recorded in the history) or view the lock history.
class _BookLockedSheet extends ConsumerWidget {
  final BookModel book;
  const _BookLockedSheet({required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when = book.lockedAt == null ? '' : ' on ${DateFormat('dd MMM yyyy').format(book.lockedAt!.toLocal())}';

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 18, 22, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lock, color: AppColors.locked, size: 18),
              SizedBox(width: 6),
              Text('This book is LOCKED - it cannot be issued',
                  style: TextStyle(color: AppColors.locked, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Text(book.title, style: Theme.of(context).textTheme.titleLarge),
          Text('${book.id} · ${book.author}', style: const TextStyle(color: AppColors.bodyText)),
          const SizedBox(height: 14),
          Text('Reason: ${book.lockReason.isEmpty ? '-' : book.lockReason}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Locked by ${book.lockedByName.isEmpty ? 'unknown' : book.lockedByName}$when',
              style: const TextStyle(color: AppColors.bodyText)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showLockHistorySheet(context, book),
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text('History'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () async {
                    await showUnlockBookDialog(context, ref, book);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: const Text('Unlock'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

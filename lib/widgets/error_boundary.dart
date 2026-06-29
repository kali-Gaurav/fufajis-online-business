import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Error boundary widget - catches errors and shows friendly message
/// Prevents blank screens when something breaks
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final String? errorTitle;
  final VoidCallback? onRetry;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorTitle,
    this.onRetry,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  late final _childrenDelegate = _ChildrenDelegate(widget.child);
  String? _error;

  @override
  void didUpdateWidget(ErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      _childrenDelegate.updateChild(widget.child);
      setState(() => _error = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorScreen(
        error: _error!,
        title: widget.errorTitle,
        onRetry: () {
          setState(() => _error = null);
          widget.onRetry?.call();
        },
      );
    }

    ErrorWidget.builder = (FlutterErrorDetails details) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _error = details.exception.toString());
        }
      });
      return const SizedBox.shrink();
    };
    return widget.child;
  }
}

class _ChildrenDelegate {
  Widget _child;

  _ChildrenDelegate(this._child);

  void updateChild(Widget newChild) {
    _child = newChild;
  }

  Widget get child => _child;
}

/// Error display screen
class _ErrorScreen extends StatelessWidget {
  final String error;
  final String? title;
  final VoidCallback onRetry;

  const _ErrorScreen({
    required this.error,
    this.title,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'त्रुटि'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppTheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'कुछ गलत हो गया',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                error.length > 100 ? '${error.substring(0, 100)}...' : error,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('पुनः कोशिश करें'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('पीछे जाएं'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Safe wrapper for AsyncSnapshot
class SafeAsyncBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  final Widget Function(BuildContext, Object)? errorBuilder;
  final Widget? loadingWidget;

  const SafeAsyncBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.errorBuilder,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return errorBuilder?.call(context, snapshot.error!) ??
              _ErrorScreen(
                error: snapshot.error.toString(),
                onRetry: () {},
              );
        }
        if (!snapshot.hasData) {
          return loadingWidget ??
              const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(AppTheme.primary),
                ),
              );
        }
        return builder(context, snapshot.data as T);
      },
    );
  }
}

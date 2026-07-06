import 'package:flutter/material.dart';
import '../utils/ui_spacer.dart';
import 'custom_app_text.dart';

class CustomBaseWidget extends StatefulWidget {
  final bool useSafeArea;
  final bool showAppBar;
  final bool showLeadingAction;
  final bool showCart;
  final Function? onBackPressed;
  final String? appBarTitle;
  final Widget body;
  final Widget? appBar;
  final Widget? bottomSheet;
  final Widget? fab;
  final bool isLoading;
  final bool extendBodyBehindAppBar;
  final double? elevation;
  final Color? appBarItemColor;
  final Color? backgroundColor;
  final Color? appBarColor;
  final Color? appBarTitleColor;
  final Color? appBarLeadingColor;
  final Widget? leading;
  final Widget? bottomNavigationBar;
  final List<Widget>? actions;
  final bool resizeToAvoidBottomInset;
  final Widget? drawer;
  final GlobalKey<ScaffoldState>? scaffoldKey;
  final bool enablePullToRefresh;
  final Future<void> Function()? onRefresh;

  const CustomBaseWidget({
    this.useSafeArea = false,
    this.showAppBar = false,
    this.showLeadingAction = true,
    this.leading,
    this.showCart = false,
    this.onBackPressed,
    this.appBarTitle = "",
    required this.body,
    this.appBar,
    this.bottomSheet,
    this.fab,
    this.isLoading = false,
    this.appBarColor,
    this.appBarTitleColor,
    this.appBarLeadingColor,
    this.elevation,
    this.extendBodyBehindAppBar = false,
    this.appBarItemColor,
    this.backgroundColor,
    this.bottomNavigationBar,
    this.actions,
    this.resizeToAvoidBottomInset = true,
    this.drawer,
    this.scaffoldKey,
    this.enablePullToRefresh = false,
    this.onRefresh,
    Key? key,
  }) : super(key: key);

  @override
  _CustomBaseWidgetState createState() => _CustomBaseWidgetState();
}

class _CustomBaseWidgetState extends State<CustomBaseWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget scaffold = Scaffold(
      key: widget.scaffoldKey,
      resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
      backgroundColor: widget.backgroundColor ?? theme.scaffoldBackgroundColor,
      extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
      appBar: widget.showAppBar
          ? (widget.appBar != null
          ? PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: widget.appBar!,
      )
          : AppBar(
        backgroundColor: widget.appBarColor ?? theme.appBarTheme.backgroundColor,
        elevation: widget.elevation ?? theme.appBarTheme.elevation,
        automaticallyImplyLeading: widget.showLeadingAction,
        leading: widget.showLeadingAction
            ? (widget.leading ??
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: widget.appBarLeadingColor ??
                    widget.appBarItemColor ??
                    theme.appBarTheme.iconTheme?.color ??
                    theme.colorScheme.onPrimary,
              ),
              onPressed: widget.onBackPressed != null
                  ? () => widget.onBackPressed!()
                  : () => Navigator.pop(context),
            ))
            : null,
        title: CustomAppText(
          widget.appBarTitle ?? "",
          style: theme.appBarTheme.titleTextStyle?.copyWith(
            color: widget.appBarTitleColor ??
                widget.appBarItemColor ??
                theme.appBarTheme.titleTextStyle?.color,
          ) ??
              theme.textTheme.titleLarge?.copyWith(
                color: widget.appBarTitleColor ??
                    widget.appBarItemColor ??
                    theme.colorScheme.onPrimary,
              ),
        ),
        actions: widget.actions,
      ))
          : null,
      body: Column(
        children: [
          widget.isLoading
              ? LinearProgressIndicator(
            color: theme.colorScheme.primary,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
          )
              : UiSpacer.emptySpace(),
          Expanded(
            child: widget.enablePullToRefresh && widget.onRefresh != null
                ? RefreshIndicator(
              onRefresh: widget.onRefresh!,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surface,
              child: widget.body,
            )
                : widget.body,
          ),
        ],
      ),
      bottomSheet: widget.bottomSheet,
      floatingActionButton: widget.fab,
      bottomNavigationBar: widget.bottomNavigationBar,
      drawer: widget.drawer,
    );

    return widget.useSafeArea
        ? SafeArea(child: scaffold)
        : scaffold;
  }
}
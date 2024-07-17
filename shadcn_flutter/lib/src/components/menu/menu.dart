import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ShortcutActivatorDisplay extends StatelessWidget {
  final ShortcutActivator activator;

  const ShortcutActivatorDisplay({required this.activator});

  @override
  Widget build(BuildContext context) {
    return Text(activator.toString());
  }
}

abstract class MenuItem extends Widget {
  bool get hasLeading;
}

class MenuDivider extends StatelessWidget implements MenuItem {
  const MenuDivider({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(
        height: 1,
        thickness: 1,
        indent: -4,
        endIndent: -4,
        color: theme.colorScheme.border,
      ),
    );
  }

  @override
  bool get hasLeading => false;
}

class MenuButton extends StatefulWidget implements MenuItem {
  final Widget child;
  final List<MenuItem>? subMenu;
  final ContextedCallback? onPressed;
  final Widget? trailing;
  final Widget? leading;
  final bool enabled;
  final FocusNode? focusNode;
  final bool autoClose;
  MenuButton({
    required this.child,
    this.subMenu,
    this.onPressed,
    this.trailing,
    this.leading,
    this.enabled = true,
    this.focusNode,
    this.autoClose = true,
  });

  @override
  State<MenuButton> createState() => _MenuButtonState();

  @override
  bool get hasLeading => leading != null;
}

class _MenuButtonState extends State<MenuButton> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void didUpdateWidget(covariant MenuButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode = widget.focusNode ?? FocusNode();
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuBarData = Data.maybeOf<MenubarState>(context);
    final menuData = Data.maybeOf<MenuData>(context);
    final menuGroupData = Data.maybeOf<MenuGroupData>(context);
    void openSubMenu() {
      menuGroupData!.closeOthers();
      menuData!.popoverController.show(
        regionGroupId: menuGroupData.root ?? menuGroupData,
        builder: (context) {
          return ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 192, // 12rem
            ),
            child: MenuGroup(
                parent: menuGroupData,
                children: widget.subMenu!,
                builder: (context, children) {
                  return MenuPopup(
                    children: children,
                  );
                }),
          );
        },
        alignment: Alignment.topLeft,
        anchorAlignment:
            menuBarData != null ? Alignment.bottomLeft : Alignment.topRight,
        offset: menuBarData != null
            ? menuBarData.widget.border
                ? const Offset(-4, 8)
                : const Offset(0, 4)
            : const Offset(8, -4 + -1),
      );
    }

    return Data<MenuGroupData>.boundary(
      child: Data<MenuData>.boundary(
        child: Data<MenubarState>.boundary(
          child: TapRegion(
            groupId: menuGroupData!.root ?? menuGroupData,
            child: PopoverPortal(
              controller: menuData!.popoverController,
              child: AnimatedBuilder(
                  animation: menuData.popoverController,
                  builder: (context, child) {
                    return Button(
                      style: (menuBarData == null
                              ? ButtonVariance.menu
                              : ButtonVariance.menubar)
                          .copyWith(
                        decoration: (context, states, value) {
                          final theme = Theme.of(context);
                          return (value as BoxDecoration).copyWith(
                            color: menuData.popoverController.hasOpenPopovers
                                ? theme.colorScheme.accent
                                : null,
                            borderRadius: BorderRadius.circular(theme.radiusMd),
                          );
                        },
                      ),
                      trailing: menuBarData != null
                          ? widget.trailing
                          : Row(
                              children: [
                                if (widget.trailing != null) widget.trailing!,
                                if (widget.subMenu != null &&
                                    menuBarData == null)
                                  const Icon(
                                    RadixIcons.chevronRight,
                                    size: 16,
                                  ),
                              ],
                            ).gap(8),
                      leading: widget.leading == null &&
                              menuGroupData.hasLeading &&
                              menuBarData == null
                          ? const SizedBox(width: 16)
                          : widget.leading == null
                              ? null
                              : SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: IconTheme.merge(
                                    data: const IconThemeData(
                                      size: 11,
                                    ),
                                    child: widget.leading!,
                                  ),
                                ),
                      disableTransition: true,
                      enabled: widget.enabled,
                      focusNode: _focusNode,
                      onHover: (value) {
                        if (value) {
                          if ((menuBarData == null ||
                                  menuGroupData.hasOpenPopovers) &&
                              widget.subMenu != null) {
                            if (!menuData.popoverController.hasOpenPopovers) {
                              openSubMenu();
                            }
                          } else {
                            menuGroupData.closeOthers();
                          }
                        }
                      },
                      onFocus: (value) {
                        if (value) {
                          if (widget.subMenu != null) {
                            if (!menuData.popoverController.hasOpenPopovers) {
                              openSubMenu();
                            }
                          } else {
                            menuGroupData.closeOthers();
                          }
                        }
                      },
                      onPressed: () {
                        widget.onPressed?.call(context);
                        if (widget.subMenu != null) {
                          if (!menuData.popoverController.hasOpenPopovers) {
                            openSubMenu();
                          }
                        } else {
                          if (widget.autoClose) {
                            menuGroupData.closeAll();
                          }
                        }
                      },
                      child: widget.child,
                    );
                  }),
            ),
          ),
        ),
      ),
    );
  }
}

class MenuGroupData {
  final MenuGroupData? root;
  final MenuGroupData? parent;
  final List<MenuData> children;
  final bool hasLeading;

  MenuGroupData(this.root, this.parent, this.children, this.hasLeading);

  bool get hasOpenPopovers {
    for (final child in children) {
      if (child.popoverController.hasOpenPopovers) {
        return true;
      }
    }
    return false;
  }

  void closeOthers() {
    for (final child in children) {
      child.popoverController.close();
    }
  }

  void closeAll() {
    root?.closeOthers();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is MenuGroupData) {
      return listEquals(children, other.children) &&
          parent == other.parent &&
          root == other.root &&
          hasLeading == other.hasLeading;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(
        children,
        parent,
        root,
        hasLeading,
      );
}

class MenuData {
  final PopoverController popoverController = PopoverController();
}

class MenuGroup extends StatefulWidget {
  final List<MenuItem> children;
  final Widget Function(BuildContext context, List<Widget> children) builder;
  final MenuGroupData? parent;

  MenuGroup({
    super.key,
    required this.children,
    required this.builder,
    this.parent,
  });

  @override
  State<MenuGroup> createState() => _MenuGroupState();
}

class _MenuGroupState extends State<MenuGroup> {
  late List<MenuData> _data;

  @override
  void initState() {
    super.initState();
    _data = List.generate(widget.children.length, (i) {
      return MenuData();
    });
  }

  @override
  void didUpdateWidget(covariant MenuGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.children, widget.children)) {
      _data = List.generate(widget.children.length, (i) {
        return MenuData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    bool hasLeading = false;
    for (int i = 0; i < widget.children.length; i++) {
      final child = widget.children[i];
      final data = _data[i];
      if (child.hasLeading) {
        hasLeading = true;
      }
      children.add(
        Data<MenuData>(
          data: data,
          child: child,
        ),
      );
    }
    return FocusTraversalGroup(
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowLeft):
              DirectionalFocusIntent(TraversalDirection.left),
          SingleActivator(LogicalKeyboardKey.arrowRight):
              DirectionalFocusIntent(TraversalDirection.right),
        },
        child: Data(
          data: MenuGroupData(widget.parent?.root ?? widget.parent,
              widget.parent, _data, hasLeading),
          child: widget.builder(context, children),
        ),
      ),
    );
  }
}

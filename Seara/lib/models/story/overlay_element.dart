/// Base class for any element that can be placed on top of story media.
///
/// Every overlay has a stable [id] for identification across screens,
/// and a [zIndex] that determines its rendering order.
/// Subclasses define the specific visual content (text, drawing, etc.).
abstract class OverlayElement {
  /// Stable identifier for this overlay. Assigned by the caller.
  final String id;

  /// Rendering order — higher values are drawn on top.
  int zIndex;

  OverlayElement({required this.id, required this.zIndex});
}

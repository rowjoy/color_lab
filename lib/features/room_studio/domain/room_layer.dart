/// Exclusive ownership labels. Zero is reserved for unselected pixels.
enum RoomLayer {
  wall,
  ceiling,
  floor,
  furniture;

  int get label => index + 1;
}

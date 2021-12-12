-- data that vspr() can draw

shape_claw = {
 {
  color = 10,
  mirror_h = false,
  mirror_v = true,
  { -1, 0 },
  { 1, 3 },
  { 3, 2 },
  { 0, 4 },
  { -3, 0 },
 },
}

shape_bullet = {
 {
  color = 7,
  mirror_h = false,
  mirror_v = true,
  { 0, 0 },
  { -1, -1 },
  { 2, 0 },
 },
}

shape_splitter = {
 {
  color = 14,
  mirror_h = false,
  mirror_v = false,
  {-1, -1},
  {1, -1},
  {1, 1},
  {-1, 1},
  {-1, -1},
 },
 {
  color = 14,
  mirror_h = false,
  mirror_v = false,
  {-1, -1},
  {1, 1},
 },
 {
  color = 14,
  mirror_h = false,
  mirror_v = false,
  {1, -1},
  {-1, 1},
 },
}

shape_pinwheel = {
 {
  color = 13,
  mirror_h = false,
  mirror_v = false,
  {0, 0},
  {0, -1},
  {-1, -1},
  {0, 0},
  {-1, 0},
  {-1, 1},
  {0, 0},
  {0, 1},
  {1, 1},
  {0, 0},
  {1, 0},
  {1, -1},
  {0, 0},
 },
}

shape_leprechaun = {
 {
  color = 11,
  mirror_h = false,
  mirror_v = false,
  {-1, -1},
  {-1, 1},
  {1, 1},
  {1, -1},
  {-1, -1},
 },
 {
  color = 11,
  mirror_h = false,
  mirror_v = false,
  {-1, 0},
  {0, -1},
  {1, 0},
  {0, 1},
  {-1, 0},
 },
}

shape_diamond = {
 {
  color = 12,
  mirror_h = false,
  mirror_v = false,
  {-1, 0},
  {0, -1},
  {1, 0},
  {0, 1},
  {-1, 0},
 },
}

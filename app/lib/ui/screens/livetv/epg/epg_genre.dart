import 'package:flutter/widgets.dart';
import 'package:moonfin_design/moonfin_design.dart';

import '../../../../data/viewmodels/live_tv_guide_view_model.dart';

/// A program's genre label + accent color, used for the program-cell accent
/// (a left bar on Material, a subtle dot on Apple). Semantic constants.
class EpgGenre {
  final String label;
  final Color color;
  const EpgGenre(this.label, this.color);
}

const _movie = Color(0xFF6C4BD8);
const _series = Color(0xFF2E7D8A);
const _sports = Color(0xFF2E8B57);
const _news = Color(0xFFC08A2E);
const _kids = Color(0xFFC0497A);

EpgGenre epgGenreFor(GuideProgram p) {
  if (p.isMovie) return const EpgGenre('Movie', _movie);
  if (p.isSports) return const EpgGenre('Sports', _sports);
  if (p.isNews) return const EpgGenre('News', _news);
  if (p.isKids) return const EpgGenre('Kids', _kids);
  if (p.isSeries) return const EpgGenre('Series', _series);
  return EpgGenre('', AppColorScheme.accent);
}

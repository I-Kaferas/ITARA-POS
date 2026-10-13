import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OnboardingStep extends Equatable {
  const OnboardingStep(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

class OnboardingCubit extends Cubit<OnboardingStep> {
  OnboardingCubit({this.length = 4}) : super(const OnboardingStep(0));

  final int length;

  void go(int index) => emit(OnboardingStep(index.clamp(0, length - 1)));

  void next() => go(state.index + 1);

  void previous() => go(state.index - 1);

  bool get isFirst => state.index == 0;

  bool get isLast => state.index == length - 1;
}

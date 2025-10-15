part of 'programs_bloc.dart';

enum ProgramsStatus { 
  initial, 
  loading, 
  loaded, 
  creating, 
  updating,
  deleting,
  activating,
  refreshing,
  error,
}

class ProgramsState extends Equatable {
  final ProgramsStatus status;
  final List<Program> programs;
  final ActiveProgram? active;
  final String? errorMessage;
  final bool isRefreshing;
  final DateTime? lastUpdated;
  final String? selectedCategory;
  final Program? programBeingModified;

  const ProgramsState({
    required this.status, 
    required this.programs, 
    this.active,
    this.errorMessage,
    this.isRefreshing = false,
    this.lastUpdated,
    this.selectedCategory,
    this.programBeingModified,
  });
  
  const ProgramsState.initial() : this(
    status: ProgramsStatus.initial, 
    programs: const [], 
    active: null,
    errorMessage: null,
    isRefreshing: false,
  );

  ProgramsState copyWith({
    ProgramsStatus? status, 
    List<Program>? programs, 
    ActiveProgram? active,
    String? errorMessage,
    bool? isRefreshing,
    DateTime? lastUpdated,
    String? selectedCategory,
    Program? programBeingModified,
  }) => ProgramsState(
        status: status ?? this.status,
        programs: programs ?? this.programs,
        active: active ?? this.active,
        errorMessage: errorMessage,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        selectedCategory: selectedCategory ?? this.selectedCategory,
        programBeingModified: programBeingModified ?? this.programBeingModified,
      );

  // Helper methods for better state checking
  bool get hasError => errorMessage != null;
  bool get isLoading => status == ProgramsStatus.loading;
  bool get isSuccess => status == ProgramsStatus.loaded && !hasError;
  bool get isEmpty => programs.isEmpty && status == ProgramsStatus.loaded;
  bool get hasActiveProgram => active != null;
  bool get isProcessing => [
    ProgramsStatus.creating,
    ProgramsStatus.updating,
    ProgramsStatus.deleting,
    ProgramsStatus.activating,
  ].contains(status);

  List<Program> get filteredPrograms {
    if (selectedCategory == null || selectedCategory!.isEmpty) {
      return programs;
    }
    return programs.where((p) => p.category == selectedCategory).toList();
  }

  @override
  List<Object?> get props => [
    status, 
    programs, 
    active, 
    errorMessage, 
    isRefreshing, 
    lastUpdated,
    selectedCategory,
    programBeingModified,
  ];
}

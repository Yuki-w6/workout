import SwiftUI

struct ExerciseListView: View {
    private enum ExerciseNavigationTarget: Hashable {
        case exercise(UUID)
    }

    @ObservedObject var viewModel: ExerciseListViewModel
    @Binding var isCloudSyncEnabled: Bool
    @State private var searchText = ""
    @State private var editingExercise: Exercise?
    @State private var draftExerciseName = ""
    @State private var isEditAlertPresented = false
    @State private var addingBodyPart: BodyPart?
    @State private var draftNewExerciseName = ""
    @State private var isAddAlertPresented = false
    @State private var isAddSheetPresented = false
    @State private var isDeleteBlockedAlertPresented = false
    @State private var toastMessage = ""
    @State private var isToastPresented = false
    @State private var isSettingsPresented = false
    @State private var isSyncing = false
    @State private var navigationPath = NavigationPath()
    @State private var isNavigating = false
    @FocusState private var isSearchFocused: Bool
    private let bannerAdUnitID: String? = Bundle.main.object(forInfoDictionaryKey: "BannerAdUnitID") as? String
    private var actionLabelColor: Color { .secondary }

    private let bodyPartSections: [(bodyPart: BodyPart, title: String)] = [
        (.chest, "胸"),
        (.back, "背中"),
        (.legs, "脚"),
        (.shoulders, "肩"),
        (.arms, "腕"),
        (.glutes, "お尻"),
        (.core, "お腹"),
        (.fullBody, "全身"),
        (.other, "その他")
    ]

    private var filteredExercises: [Exercise] {
        viewModel.exercises(matching: searchText)
    }

    private var filteredPresets: [PresetExerciseDefinition] {
        viewModel.availablePresets(matching: searchText)
    }

    private func exercises(for bodyPart: BodyPart) -> [Exercise] {
        filteredExercises.filter { $0.bodyPart == bodyPart }
    }

    private func presets(for bodyPart: BodyPart) -> [PresetExerciseDefinition] {
        filteredPresets.filter { $0.bodyPart == bodyPart }
    }

    var body: some View {
        ZStack {
            NavigationStack(path: $navigationPath) {
                Group {
                    if isSyncing && viewModel.exercises.isEmpty {
                        skeletonContent
                    } else {
                        listContent
                    }
                }
                    .contentShape(Rectangle())
                    .onAppear {
                        viewModel.load()
                        refreshSyncingState()
                    }
                    .alert("種目名を変更", isPresented: $isEditAlertPresented) {
                        TextField("種目名", text: $draftExerciseName)
                        Button("保存") {
                            guard let exercise = editingExercise else {
                                return
                            }
                            viewModel.updateExercise(
                                id: exercise.id,
                                name: draftExerciseName,
                                bodyPart: exercise.bodyPart
                            )
                            editingExercise = nil
                        }
                        Button("キャンセル", role: .cancel) {
                            editingExercise = nil
                        }
                    } message: {
                        Text("新しい種目名を入力してください")
                    }
                    .alert("削除できません", isPresented: $isDeleteBlockedAlertPresented) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("記録のある種目は削除できません。")
                    }
                    .sheet(isPresented: $isAddSheetPresented) {
                        AddExerciseSheet(
                            isPresented: $isAddSheetPresented,
                            bodyPart: addingBodyPart,
                            initialName: draftNewExerciseName,
                            onAdd: { name, bodyPart in
                                viewModel.addExercise(name: name, bodyPart: bodyPart)
                                addingBodyPart = nil
                            },
                            onCancel: {
                                addingBodyPart = nil
                            }
                        )
                    }
                    .onChange(of: isEditAlertPresented) { _, newValue in
                        if !newValue {
                            editingExercise = nil
                        }
                    }
                    .onChange(of: isAddAlertPresented) { _, newValue in
                        if !newValue {
                            addingBodyPart = nil
                        }
                    }
                    .onChange(of: isAddSheetPresented) { _, newValue in
                        if !newValue {
                            addingBodyPart = nil
                        }
                    }
                    .toast(message: toastMessage, isPresented: $isToastPresented)
                    .safeAreaInset(edge: .top) {
                        searchBar
                    }
                    .safeAreaInset(edge: .bottom) {
                        if let adUnitID = bannerAdUnitID, !adUnitID.isEmpty {
                            BannerAdView(adUnitID: adUnitID)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .padding(.horizontal, 16)
                        }
                    }
                    .navigationDestination(for: ExerciseNavigationTarget.self) { target in
                        switch target {
                        case .exercise(let id):
                            ExerciseDetailView(
                                viewModel: viewModel,
                                exerciseID: id,
                                exercise: viewModel.exercise(id: id),
                                isNewRecord: true,
                                initialDate: nil,
                                onSave: { message in
                                    showToast(message)
                                }
                            )
                            .onAppear {
                                isNavigating = false
                            }
                        }
                    }
            }

            SettingsSideSheet(isPresented: $isSettingsPresented, isCloudSyncEnabled: $isCloudSyncEnabled)

            if isNavigating {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 6)
                        )
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            refreshSyncingState()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isSettingsPresented = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(actionLabelColor)
            }
            .accessibilityLabel("設定メニューを開く")
            .tint(actionLabelColor)

            TextField("種目を検索", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($isSearchFocused)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(actionLabelColor)
                }
                .accessibilityLabel("検索をクリア")
                .tint(actionLabelColor)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var listContent: some View {
        List {
            ForEach(bodyPartSections, id: \.bodyPart) { section in
                let sectionPresets = presets(for: section.bodyPart)
                let sectionExercises = exercises(for: section.bodyPart)
                Section(section.title) {
                    ForEach(sectionPresets, id: \.seedKey) { preset in
                        presetRow(preset)
                    }
                    ForEach(sectionExercises, id: \.id) { exercise in
                        exerciseRow(exercise)
                    }

                    addExerciseButton(for: section.bodyPart)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var skeletonContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 6) {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(.tertiarySystemFill))
                                .frame(width: 32, height: 8)
                        }
                        .frame(height: 14, alignment: .center)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(0..<3, id: \.self) { index in
                                ZStack(alignment: .bottomLeading) {
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(.tertiarySystemFill))
                                            .frame(width: 200, height: 28)
                                    }
                                    .frame(height: 52, alignment: .center)
                                    if index < 2 {
                                        Divider()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.top, index == 0 ? 0 : 3)
                    .padding(.bottom, index == 2 ? 0 : 3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 0)
        }
        .redacted(reason: .placeholder)
        .background(Color(.systemGroupedBackground))
    }

    private func refreshSyncingState() {
        isSyncing = false
        viewModel.load()
    }

    @ViewBuilder
    private func exerciseRow(_ exercise: Exercise) -> some View {
        HStack {
            Text(exercise.name)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isNavigating = true
            navigationPath.append(ExerciseNavigationTarget.exercise(exercise.id))
        }
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .trailing, allowsFullSwipe: !isPresetLike(exercise)) {
            if !isPresetLike(exercise) {
                Button(role: .destructive) {
                    let failedIds = viewModel.deleteExercises(ids: [exercise.id])
                    if !failedIds.isEmpty {
                        isDeleteBlockedAlertPresented = true
                        return
                    }
                } label: {
                    Label("削除", systemImage: "trash")
                }
            }
            Button {
                editingExercise = exercise
                draftExerciseName = exercise.name
                isEditAlertPresented = true
            } label: {
                Label("編集", systemImage: "pencil")
            }
        }
    }

    private func presetRow(_ preset: PresetExerciseDefinition) -> some View {
        HStack {
            Text(preset.name)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard let exercise = viewModel.ensureExercise(for: preset) else { return }
            isNavigating = true
            navigationPath.append(ExerciseNavigationTarget.exercise(exercise.id))
        }
        .accessibilityAddTraits(.isButton)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                guard let exercise = viewModel.ensureExercise(for: preset) else { return }
                editingExercise = exercise
                draftExerciseName = exercise.name
                isEditAlertPresented = true
            } label: {
                Label("編集", systemImage: "pencil")
            }
        }
    }

    private func addExerciseButton(for bodyPart: BodyPart) -> some View {
        Button {
            addingBodyPart = bodyPart
            draftNewExerciseName = ""
            isAddSheetPresented = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("種目を追加")
            }
            .font(.subheadline)
            .foregroundStyle(actionLabelColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .tint(actionLabelColor)
        .buttonStyle(.plain)
    }

    private func showToast(_ message: String) {
        toastMessage = message
        withAnimation(.easeInOut(duration: 0.2)) {
            isToastPresented = true
        }
    }

    private func isPresetLike(_ exercise: Exercise) -> Bool {
        PresetExerciseDefinitions.all.contains { preset in
            preset.name == exercise.name && preset.bodyPart.rawValue == exercise.bodyPartRaw
        }
    }

}

private struct AddExerciseSheet: View {
    @Binding var isPresented: Bool
    let bodyPart: BodyPart?
    @State private var name: String
    @FocusState private var isNameFocused: Bool
    let onAdd: (String, BodyPart) -> Void
    let onCancel: () -> Void

    init(
        isPresented: Binding<Bool>,
        bodyPart: BodyPart?,
        initialName: String,
        onAdd: @escaping (String, BodyPart) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _isPresented = isPresented
        self.bodyPart = bodyPart
        _name = State(initialValue: initialName)
        self.onAdd = onAdd
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("種目名", text: $name)
                        .focused($isNameFocused)
                } footer: {
                    Text("種目名を入力してください")
                }
            }
            .navigationTitle("種目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        onCancel()
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        guard let bodyPart else { return }
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalName = trimmedName.isEmpty ? "新しい種目" : trimmedName
                        onAdd(finalName, bodyPart)
                        isPresented = false
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    isNameFocused = true
                }
            }
        }
    }
}

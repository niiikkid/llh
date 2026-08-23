//
//  Phase3ManageProfilesUseCaseTests.swift
//  llhTests
//

import Foundation
import Testing
@testable import llh

@MainActor
private func makeProfilesUseCase() -> ManageProfilesUseCase {
    ManageProfilesUseCase(manageHistoryUseCase: ManageHistoryUseCase(historyRepository: JSONHistoryRepository()))
}

@MainActor
struct Phase3ManageProfilesUseCaseTests {
    @Test
    func normalizedProfileName_usesPlaceholderWhenEmpty() {
        #expect(ManageProfilesUseCase.normalizedProfileName(from: "   ") == "Новый профиль")
        #expect(ManageProfilesUseCase.normalizedProfileName(from: "  My Profile  ") == "My Profile")
    }

    @Test
    @MainActor
    func createProfile_insertsAtZeroAndSelectsProfile() {
        let defaultProfile = LearningProfile.defaultProfile()
        var state = HistorySessionState(
            profiles: [defaultProfile],
            selectedProfileID: defaultProfile.id,
            selectedEntryID: nil
        )
        let useCase = makeProfilesUseCase()

        let created = useCase.createProfile(state: &state, named: "  Chinese  ", learningLanguage: .chinese)

        #expect(state.profiles.count == 2)
        #expect(state.profiles[0].id == created.id)
        #expect(state.profiles[0].name == "Chinese")
        #expect(state.profiles[0].learningLanguage == .chinese)
        #expect(state.selectedProfileID == created.id)
        #expect(state.selectedEntryID == nil)
    }

    @Test
    @MainActor
    func selectProfile_resolvesPersistedEntrySelection() {
        let first = CapturedTextEntry(text: "a")
        let second = CapturedTextEntry(text: "b")
        let profileA = LearningProfile(
            name: "A",
            history: [first, second],
            selectedEntryID: second.id
        )
        let profileB = LearningProfile(name: "B", history: [CapturedTextEntry(text: "c")])
        var state = HistorySessionState(
            profiles: [profileA, profileB],
            selectedProfileID: profileB.id,
            selectedEntryID: nil
        )
        let useCase = makeProfilesUseCase()

        useCase.selectProfile(state: &state, profileID: profileA.id)

        #expect(state.selectedProfileID == profileA.id)
        #expect(state.selectedEntryID == second.id)
    }

    @Test
    @MainActor
    func selectProfile_nilClearsEntrySelection() {
        let profile = LearningProfile.defaultProfile()
        var state = HistorySessionState(
            profiles: [profile],
            selectedProfileID: profile.id,
            selectedEntryID: nil
        )
        let useCase = makeProfilesUseCase()

        useCase.selectProfile(state: &state, profileID: nil)

        #expect(state.selectedProfileID == nil)
        #expect(state.selectedEntryID == nil)
    }

    @Test
    @MainActor
    func canDeleteSelectedProfile_falseForDefault() {
        let defaultProfile = LearningProfile.defaultProfile()
        let state = HistorySessionState(
            profiles: [defaultProfile],
            selectedProfileID: defaultProfile.id,
            selectedEntryID: nil
        )
        let useCase = makeProfilesUseCase()

        #expect(useCase.canDeleteSelectedProfile(state: state) == false)
    }

    @Test
    @MainActor
    func deleteSelectedProfile_rejectsDefaultProfile() {
        let defaultProfile = LearningProfile.defaultProfile()
        var state = HistorySessionState(
            profiles: [defaultProfile],
            selectedProfileID: defaultProfile.id,
            selectedEntryID: nil
        )
        let useCase = makeProfilesUseCase()

        let outcome = useCase.deleteSelectedProfile(state: &state)

        #expect(outcome == .cannotDeleteDefaultProfile)
        #expect(state.profiles.count == 1)
        #expect(state.selectedProfileID == defaultProfile.id)
    }

    @Test
    @MainActor
    func deleteSelectedProfile_removesCustomAndSelectsFirst() {
        let defaultProfile = LearningProfile.defaultProfile()
        let custom = LearningProfile(name: "Custom", learningLanguage: .english)
        var state = HistorySessionState(
            profiles: [defaultProfile, custom],
            selectedProfileID: custom.id,
            selectedEntryID: nil
        )
        let useCase = makeProfilesUseCase()

        let outcome = useCase.deleteSelectedProfile(state: &state)

        #expect(outcome == .deleted(removedName: "Custom"))
        #expect(state.profiles.count == 1)
        #expect(state.profiles[0].isDefaultProfile)
        #expect(state.selectedProfileID == defaultProfile.id)
    }

    @Test
    @MainActor
    func deleteSelectedProfile_noSelectedProfile() {
        var state = HistorySessionState(profiles: [], selectedProfileID: nil, selectedEntryID: nil)
        let useCase = makeProfilesUseCase()

        let outcome = useCase.deleteSelectedProfile(state: &state)

        #expect(outcome == .noSelectedProfile)
    }

    @Test
    @MainActor
    func createProfile_persistsSessionAutomationFlags() {
        var state = HistorySessionState(profiles: [], selectedProfileID: nil, selectedEntryID: nil)
        let useCase = makeProfilesUseCase()

        let profile = useCase.createProfile(
            state: &state,
            named: "Chinese",
            learningLanguage: .chinese,
            automaticallyLoadWords: true
        )

        #expect(profile.automaticallyLoadWords)
        #expect(!profile.automaticallyLoadGrammar)
        #expect(state.profiles[0].automaticallyLoadWords)
        #expect(!state.profiles[0].automaticallyLoadGrammar)
    }

    @Test
    @MainActor
    func updateSessionAutomation_updatesProfileFlags() {
        let custom = LearningProfile(name: "Study", learningLanguage: .english)
        var state = HistorySessionState(
            profiles: [custom],
            selectedProfileID: custom.id,
            selectedEntryID: nil
        )
        let useCase = makeProfilesUseCase()

        let outcome = useCase.updateSessionAutomation(
            state: &state,
            profileID: custom.id,
            automaticallyLoadWords: true,
            showWordsInCompactOverlay: true
        )

        #expect(outcome == .updated)
        #expect(state.profiles[0].automaticallyLoadWords)
        #expect(!state.profiles[0].automaticallyLoadGrammar)
        #expect(state.profiles[0].showWordsInCompactOverlay)
    }

    @Test
    @MainActor
    func renameProfile_updatesStoredName() {
        let custom = LearningProfile(name: "Old", learningLanguage: .spanish)
        var state = HistorySessionState(
            profiles: [custom],
            selectedProfileID: custom.id,
            selectedEntryID: nil
        )
        let useCase = makeProfilesUseCase()

        let outcome = useCase.renameProfile(state: &state, profileID: custom.id, named: "  New Name  ")

        #expect(outcome == .renamed(displayName: "New Name"))
        #expect(state.profiles[0].name == "New Name")
        #expect(state.profiles[0].learningLanguage == .spanish)
    }

    @Test
    @MainActor
    func renameProfile_profileNotFound() {
        var state = HistorySessionState(profiles: [], selectedProfileID: nil, selectedEntryID: nil)
        let useCase = makeProfilesUseCase()

        let outcome = useCase.renameProfile(
            state: &state,
            profileID: UUID(),
            named: "Name"
        )

        #expect(outcome == .profileNotFound)
    }

    @Test
    @MainActor
    func deleteProfile_nonSelected_keepsSelection() {
        let defaultProfile = LearningProfile.defaultProfile()
        let customA = LearningProfile(name: "A", learningLanguage: .english)
        let customB = LearningProfile(name: "B", learningLanguage: .chinese)
        var state = HistorySessionState(
            profiles: [defaultProfile, customA, customB],
            selectedProfileID: customA.id,
            selectedEntryID: nil
        )
        let useCase = makeProfilesUseCase()

        let outcome = useCase.deleteProfile(state: &state, profileID: customB.id)

        #expect(outcome == .deleted(removedName: "B"))
        #expect(state.profiles.count == 2)
        #expect(state.selectedProfileID == customA.id)
    }

    @Test
    @MainActor
    func deleteProfile_profileNotFound() {
        var state = HistorySessionState(profiles: [], selectedProfileID: nil, selectedEntryID: nil)
        let useCase = makeProfilesUseCase()

        let outcome = useCase.deleteProfile(state: &state, profileID: UUID())

        #expect(outcome == .profileNotFound)
    }
}

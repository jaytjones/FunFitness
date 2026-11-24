//
//  FriendsProfileSection.swift
//  FunFitness
//
//  Friends in Profile (3.4 step 2; Jay chose a Profile section over a tab for now): Sign in with
//  Apple, create the Friends profile (name + emoji; style comes along), sharing switches (all off
//  until turned on), "How Friends works", sign out and delete.
//
//  UNRELEASED — compiled only with INTERNAL_SOCIAL; text is verbatim until launch.
//

#if INTERNAL_SOCIAL
import SwiftUI
import AuthenticationServices

struct FriendsProfileSection: View {
    /// The person's current style, carried onto their Friends profile.
    let styleID: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var session = SocialSession.shared
    @State private var showHowItWorks = false
    @State private var showDeleteConfirm = false
    @State private var isEditingName = false
    @State private var nameDraft = ""
    @State private var emojiDraft = FriendsProfileSection.emojis[0]
    @State private var codeDraft = ""
    @State private var friendToBlock: SocialProfile?

    static let emojis = ["🦛", "🐘", "🦒", "🐢", "🦖", "🐙", "🦊", "🐧", "🦄", "🐝", "🍕", "🚀"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(verbatim: "Friends (internal)")
                    .ffFont(.headline)
                    .foregroundStyle(Color.ffInk)
                Spacer()
                Button {
                    showHowItWorks = true
                } label: {
                    Text(verbatim: "How Friends works")
                        .ffFont(.caption)
                        .foregroundStyle(Color.ffLink)
                }
                .accessibilityIdentifier("friendsHowItWorksButton")
            }
            .padding(.horizontal)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .ffCard()
                .padding(.horizontal)
        }
        .task {
            session.observeRevocation()
            await session.refresh()
            await session.refreshFriends()
        }
        .onChange(of: styleID) {
            // Keep the Friends profile wearing the current style.
            guard case .ready(var profile) = session.state, profile.styleID != styleID else { return }
            profile.styleID = styleID
            Task { await session.update(profile) }
        }
        .sheet(isPresented: $showHowItWorks) {
            NavigationStack { HowFriendsWorksView() }
        }
        .sheet(item: Binding(get: { session.newInvite }, set: { if $0 == nil { session.dismissNewInvite() } })) { invite in
            NavigationStack { InviteSheet(invite: invite) }
                .presentationDetents([.medium])
        }
        .confirmationDialog(
            Text(verbatim: "Block \(friendToBlock?.displayName ?? "this friend")?"),
            isPresented: Binding(get: { friendToBlock != nil }, set: { if !$0 { friendToBlock = nil } }),
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                if let friend = friendToBlock { Task { await session.block(friend.id) } }
            } label: {
                Text(verbatim: "Block")
            }
        } message: {
            Text(verbatim: "You'll stop seeing each other, and invites between you won't work. They aren't told.")
        }
        .confirmationDialog(
            Text(verbatim: "Delete your Friends profile?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                Task { await session.deleteProfile() }
            } label: {
                Text(verbatim: "Delete Friends Profile")
            }
        } message: {
            Text(verbatim: "Your Friends profile and anything you've shared are removed, and you disappear from friends' lists. Your workouts stay on your devices.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.state {
        case .checking:
            HStack(spacing: 8) {
                SwiftUI.ProgressView()
                Text(verbatim: "Checking…").ffFont(.caption).foregroundStyle(Color.ffInkMuted)
            }
        case .signedOut:
            signedOut
        case .iCloudUnavailable:
            note("Friends keeps your profile in iCloud. Sign in to iCloud in Settings to use it.")
        case .needsProfile:
            createProfile
        case .ready(let profile):
            ready(profile)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 10) {
                note(message)
                Button {
                    Task { await session.refresh() }
                } label: {
                    Text(verbatim: "Try Again")
                }
                .buttonStyle(.ffSecondary)
            }
        }
    }

    // MARK: States

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "Add friends by invite, trade high fives and run weekly Effort Points duels.")
                .ffFont(.body)
                .foregroundStyle(Color.ffInk)
            note("Uses Sign in with Apple. For now, friends need an Apple device signed in to iCloud. Nothing about you is shared until you turn it on.")
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = []   // no name or email: people choose a display name
            } onCompletion: { result in
                guard case .success(let authorization) = result,
                      let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
                Task { await session.signedIn(appleUserID: credential.user) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 48)
            .accessibilityIdentifier("friendsSignInButton")
        }
    }

    private var createProfile: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: "Create your Friends profile")
                .ffFont(.bodyStrong)
                .foregroundStyle(Color.ffInk)
            TextField(text: $nameDraft) { Text(verbatim: "Display name") }
                .ffFont(.body)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .ffWell(radius: FFRadius.sm)
                .textInputAutocapitalization(.words)
                .accessibilityIdentifier("friendsNameField")
            emojiPicker
            note("Friends see your name, emoji and style. Everything else is off until you turn it on.")
            Button {
                Task { await session.createProfile(name: nameDraft, emoji: emojiDraft, styleID: styleID) }
            } label: {
                Text(verbatim: "Create Profile")
            }
            .buttonStyle(.ffPrimary)
            .disabled(SocialProfile.cleanedName(nameDraft) == nil || session.isWorking)
            signOutButton
        }
    }

    private func ready(_ profile: SocialProfile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(profile.avatarEmoji).font(.largeTitle).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName).ffFont(.headline).foregroundStyle(Color.ffInk)
                    Text(verbatim: "Your Friends profile").ffFont(.caption).foregroundStyle(Color.ffInkMuted)
                }
                Spacer()
                Button {
                    nameDraft = profile.displayName
                    emojiDraft = profile.avatarEmoji
                    isEditingName.toggle()
                } label: {
                    Text(verbatim: isEditingName ? "Cancel" : "Edit")
                }
                .ffFont(.bodyStrong)
                .foregroundStyle(Color.ffLink)
            }
            .padding(.bottom, 12)

            if isEditingName {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(text: $nameDraft) { Text(verbatim: "Display name") }
                        .ffFont(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .ffWell(radius: FFRadius.sm)
                    emojiPicker
                    Button {
                        var edited = profile
                        edited.displayName = SocialProfile.cleanedName(nameDraft) ?? profile.displayName
                        edited.avatarEmoji = emojiDraft
                        isEditingName = false
                        Task { await session.update(edited) }
                    } label: {
                        Text(verbatim: "Save")
                    }
                    .buttonStyle(.ffPrimary)
                    .disabled(SocialProfile.cleanedName(nameDraft) == nil)
                }
                .padding(.bottom, 12)
            }

            Divider()
            friendsList
            Divider()
            Text(verbatim: "What friends see")
                .ffFont(.bodyStrong)
                .foregroundStyle(Color.ffInk)
                .padding(.top, 12)
            Text(verbatim: "Your name, emoji and style, plus only what you turn on here. Your workouts are never shared.")
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
            sharingToggle("Badges and challenges", "Your unlocks appear in friends' feeds.", \.shareUnlocks, profile)
            sharingToggle("Streak milestones", "When your streak hits a new mark.", \.shareStreak, profile)
            sharingToggle("Weekly Effort Points", "Needed for duels and the friends leaderboard.", \.shareWeeklyEffort, profile)

            Divider().padding(.bottom, 12)
            HStack {
                signOutButton
                Spacer()
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Text(verbatim: "Delete Friends Profile")
                }
                .ffFont(.bodyStrong)
                .foregroundStyle(Color.ffDanger)
                .accessibilityIdentifier("friendsDeleteButton")
            }
        }
    }

    // MARK: Friends and invites (step 3)

    private var friendsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(verbatim: session.friends.isEmpty ? "Friends" : "Friends · \(session.friends.count)")
                .ffFont(.bodyStrong)
                .foregroundStyle(Color.ffInk)
                .padding(.top, 12)

            if session.friends.isEmpty {
                Text(verbatim: "No friends yet. Send an invite, or enter a friend's code below.")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }
            ForEach(session.friends) { friend in
                HStack(spacing: 10) {
                    Text(friend.avatarEmoji).font(.title2).accessibilityHidden(true)
                    Text(friend.displayName).ffFont(.body).foregroundStyle(Color.ffInk)
                    Spacer()
                    Menu {
                        Button(role: .destructive) {
                            Task { await session.removeFriend(friend.id) }
                        } label: {
                            Label { Text(verbatim: "Remove Friend") } icon: { Image(systemName: "person.badge.minus") }
                        }
                        Button(role: .destructive) {
                            friendToBlock = friend
                        } label: {
                            Label { Text(verbatim: "Block") } icon: { Image(systemName: "hand.raised") }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.ffInkMuted)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text(verbatim: "Options for \(friend.displayName)"))
                }
                .accessibilityElement(children: .contain)
            }

            Button {
                Task { await session.createInvite() }
            } label: {
                Label { Text(verbatim: "Invite a Friend") } icon: { Image(systemName: "envelope.badge") }
            }
            .buttonStyle(.ffSecondary)
            .disabled(session.isWorking)
            .accessibilityIdentifier("friendsInviteButton")

            if !session.openInvites.isEmpty {
                Text(verbatim: "Waiting on \(session.openInvites.count) invite\(session.openInvites.count == 1 ? "" : "s"): \(session.openInvites.map(\.code).formatted(.list(type: .and)))")
                    .ffFont(.caption)
                    .foregroundStyle(Color.ffInkMuted)
            }

            HStack(spacing: 8) {
                TextField(text: $codeDraft) { Text(verbatim: "Friend's code") }
                    .ffFont(.body)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .ffWell(radius: FFRadius.sm)
                    .accessibilityIdentifier("friendsCodeField")
                Button {
                    let code = codeDraft
                    codeDraft = ""
                    Task { await session.acceptInvite(code: code) }
                } label: {
                    Text(verbatim: "Add")
                }
                .buttonStyle(.ffPrimary)
                .fixedSize()
                .disabled(FriendInvite.normalizedCode(codeDraft) == nil || session.isWorking)
            }
            if let message = session.inviteMessage {
                note(message)
            }
        }
        .padding(.bottom, 12)
    }

    // MARK: Pieces

    private var emojiPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.emojis, id: \.self) { emoji in
                    Button {
                        emojiDraft = emoji
                    } label: {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(emojiDraft == emoji ? Color.ffAccent.opacity(0.25) : Color.clear, in: .circle)
                            .overlay(Circle().strokeBorder(emojiDraft == emoji ? Color.ffAccent : Color.ffLine, lineWidth: FFStroke.control))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(emojiDraft == emoji ? .isSelected : [])
                }
            }
        }
    }

    private var signOutButton: some View {
        Button {
            session.signOut()
        } label: {
            Text(verbatim: "Sign Out")
        }
        .ffFont(.bodyStrong)
        .foregroundStyle(Color.ffLink)
    }

    private func sharingToggle(
        _ title: String, _ subtitle: String, _ keyPath: WritableKeyPath<SharingSettings, Bool>, _ profile: SocialProfile
    ) -> some View {
        Toggle(isOn: Binding(
            get: { profile.sharing[keyPath: keyPath] },
            set: { isOn in
                var edited = profile
                edited.sharing[keyPath: keyPath] = isOn
                Task { await session.update(edited) }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).ffFont(.body).foregroundStyle(Color.ffInk)
                Text(verbatim: subtitle).ffFont(.caption).foregroundStyle(Color.ffInkMuted)
            }
        }
        .tint(Color.ffAccent)
        .padding(.vertical, 8)
    }

    private func note(_ text: String) -> some View {
        Text(verbatim: text)
            .ffFont(.caption)
            .foregroundStyle(Color.ffInkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Shows a new invite: the code to read out, and the link to send (Jay: both).
private struct InviteSheet: View {
    let invite: FriendInvite
    @Environment(\.dismiss) private var dismiss

    private var spacedCode: String {
        let code = invite.code
        return "\(code.prefix(3)) \(code.suffix(3))"
    }

    private var shareText: String {
        let link = invite.link?.absoluteString ?? ""
        return "Be my FunFitness friend! Open \(link) or enter code \(invite.code) in Profile › Friends. Good for 7 days."
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(verbatim: "Your invite code")
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
            Text(verbatim: spacedCode)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.ffInk)
                .textSelection(.enabled)
                .accessibilityLabel(Text(verbatim: invite.code.map(String.init).joined(separator: " ")))
            Text(verbatim: "Good for 7 days, for one friend. You'll be friends once they enter it and you next open FunFitness.")
                .ffFont(.caption)
                .foregroundStyle(Color.ffInkMuted)
                .multilineTextAlignment(.center)
            ShareLink(item: shareText) {
                Label { Text(verbatim: "Send Invite Link") } icon: { Image(systemName: "square.and.arrow.up") }
            }
            .buttonStyle(.ffPrimary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ffBg.ignoresSafeArea())
        .navigationTitle(Text(verbatim: "Invite a Friend"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: { Text(verbatim: "Done") }
            }
        }
    }
}

/// The plain-language limits of Friends (Jay, 2026-11-24: users must be told). Source list:
/// docs/20261124_3.4_design_decisions.md › Limitations.
struct HowFriendsWorksView: View {
    @Environment(\.dismiss) private var dismiss

    private let points: [(emoji: String, title: String, body: String)] = [
        ("🍎", "Apple devices only, for now",
         "Friends uses Sign in with Apple and iCloud, so you and your friends need an iPhone (or other Apple device) signed in to iCloud. Friends on Android or the web can't join yet."),
        ("💌", "Friends by invite only",
         "Add people by sending an invite link or showing a short code. There's no search, no contacts upload and no public leaderboard. Just people you invite."),
        ("🙈", "You choose what's shared",
         "Friends see your name, emoji and style. Badges, streaks and weekly Effort Points are shared only if you turn them on. Your workouts themselves are never shared."),
        ("☁️", "Where it's kept",
         "Your Friends profile lives in your own iCloud and is shared only with the friends you add. Apple's iCloud decides who can see it."),
        ("🤝", "Duels are on the honor system",
         "Duel totals come from each person's own app and aren't checked by anyone, so they're for fun between friends."),
        ("📶", "Updates need a connection",
         "High fives and duel results arrive over the internet and can take a moment to show up."),
        ("🧳", "If FunFitness comes to more devices",
         "Your account will carry over. Older feed items and finished duels might not."),
        ("🗑️", "Leaving is easy",
         "Delete your Friends profile in Profile at any time. You'll disappear from friends' lists, and your workouts stay on your devices."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(points, id: \.title) { point in
                    HStack(alignment: .top, spacing: 12) {
                        Text(point.emoji).font(.title2).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: point.title).ffFont(.bodyStrong).foregroundStyle(Color.ffInk)
                            Text(verbatim: point.body)
                                .ffFont(.body)
                                .foregroundStyle(Color.ffInkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .ffCard()
            .padding()
        }
        .background(Color.ffBg.ignoresSafeArea())
        .navigationTitle(Text(verbatim: "How Friends works"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button { dismiss() } label: { Text(verbatim: "Done") }
            }
        }
    }
}
#endif

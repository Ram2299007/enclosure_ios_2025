import SwiftUI

// MARK: - Story viewer config (atomic presentation)
private struct StoryViewerConfig: Identifiable {
    let id = UUID()
    let stories: [UserStory]
    let ownerUid: String
    let ownerName: String
    let ownerPhotoURL: URL?
    let isOwnStory: Bool
    let startIndex: Int
}

// MARK: - Story Bottom Sheet
struct StoryBottomSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var uploadManager = StoryUploadManager.shared
    @State private var showPhotoPicker = false
    @State private var now = Date()
    @State private var isExpanded = true   // collapse / expand My Stories cards
    @State private var collapsedContacts: Set<String> = []  // contacts NOT here are expanded

    // Search
    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var isSearchFieldFocused: Bool

    // Story viewer — single atomic config avoids race between index + isPresented
    @State private var storyViewerConfig: StoryViewerConfig? = nil

    // Queue-based presentation for contact stories (may include ads between groups)
    @State private var queuePresentation: StoryQueuePresentation? = nil

    // Ads
    @State private var loadedAds: [AdData] = []
    @State private var myOwnAds: [AdData] = []
    @State private var shownAdIdsToday: Set<String> = []
    @State private var showPostAd = false
    private let adInterval = 1  // insert ad every N contact groups (matches Android AD_INTERVAL)

    @State private var showPrivacySheet = false

    // Hide user
    @State private var hideTargetGroup: ContactStoryGroup? = nil
    @State private var hiddenUids: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "hiddenStoryUids") ?? [])
    }()
    @State private var isHiddenSectionExpanded = false
    @State private var collapsedHidden: Set<String> = []

    // Seen story IDs (local, loaded from UserDefaults) — drives ring color
    @State private var localSeenIds: Set<String> = {
        Set(UserDefaults.standard.stringArray(forKey: "localSeenStoryIds") ?? [])
    }()

    // UserInfoScreen navigation
    @State private var selectedContactGroup: ContactStoryGroup? = nil
    @State private var showMyUserInfo = false

    private var myProfileImageURL: String {
        UserDefaults.standard.string(forKey: Constant.profilePic) ?? ""
    }

    private var myProfileFullURL: URL? {
        let raw = myProfileImageURL
        guard !raw.isEmpty else { return nil }
        let full = raw.hasPrefix("http") ? raw : Constant.baseURL + raw
        return URL(string: full)
    }

    /// Returns true if every story in the group has been locally seen.
    private func isGroupAllSeen(_ group: ContactStoryGroup) -> Bool {
        !group.stories.isEmpty && group.stories.allSatisfy { localSeenIds.contains($0.id) }
    }

    private var visibleGroups: [ContactStoryGroup] {
        let groups = uploadManager.contactStoryGroups.filter { !hiddenUids.contains($0.id) }
        // Unseen groups first (most recent), then fully-seen groups (most recent)
        let unseen = groups.filter { !isGroupAllSeen($0) }.sorted { ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast) }
        let seen   = groups.filter {  isGroupAllSeen($0) }.sorted { ($0.latestDate ?? .distantPast) > ($1.latestDate ?? .distantPast) }
        return unseen + seen
    }

    private var hiddenGroups: [ContactStoryGroup] {
        uploadManager.contactStoryGroups.filter { hiddenUids.contains($0.id) }
    }

    private var filteredVisibleGroups: [ContactStoryGroup] {
        guard !searchText.isEmpty else { return visibleGroups }
        return visibleGroups.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }

    private var hasStories: Bool {
        !uploadManager.myStories.isEmpty || uploadManager.isUploading || !myOwnAds.isEmpty
    }

    private var subtitleText: String {
        if uploadManager.isUploading {
            let pct = Int(uploadManager.progress * 100)
            return pct > 0 ? "Posting stories... \(pct)%" : "Posting stories..."
        }
        if let posted = uploadManager.lastPostedAt {
            return relativeTime(from: posted)
        }
        return "Tap to add story"
    }

    private var subtitleColor: Color {
        (uploadManager.isUploading || uploadManager.lastPostedAt != nil)
            ? Color(hex: Constant.themeColor) : Color("gray3")
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Top header (sticky) ──────────────────────────────────────
            HStack(spacing: 10) {
                if isSearchActive {
                    // Back arrow
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { isSearchActive = false }
                        searchText = ""
                        isSearchFieldFocused = false
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("TextColor"))
                    }
                    // Search field
                    TextField("Search name...", text: $searchText)
                        .font(.custom("Inter18pt-Regular", size: 15))
                        .foregroundColor(Color("TextColor"))
                        .focused($isSearchFieldFocused)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .frame(maxWidth: .infinity)
                    // Clear button
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 17))
                                .foregroundColor(Color("gray3"))
                        }
                    }
                } else {
                    Text("Stories")
                        .font(.custom("Inter18pt-Bold", size: 24))
                        .foregroundColor(Color("TextColor"))
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { isSearchActive = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            isSearchFieldFocused = true
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(Color(hex: Constant.themeColor))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 12)
            .background(Color("BackgroundColor"))

            // ── Scrollable content ───────────────────────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {

                    // ── My Stories container ──
                    VStack(spacing: 0) {
                    // My Stories row
                    HStack(spacing: 10) {
                        if hasStories {
                            ZStack(alignment: .bottomTrailing) {
                                profileImage(size: 50)
                            }
                            .onTapGesture { showMyUserInfo = true }
                        } else {
                            Menu {
                                Button { showPhotoPicker = true } label: {
                                    Label("Add Story", systemImage: "plus.circle")
                                }
                                Button { showPostAd = true } label: {
                                    Label("Promote Post", systemImage: "megaphone")
                                }
                            } label: {
                                ZStack(alignment: .bottomTrailing) {
                                    profileImage(size: 50)
                                    plusBadge
                                }
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("My Stories")
                                .font(.custom("Inter18pt-SemiBold", size: 15))
                                .foregroundColor(Color(hex: Constant.themeColor))
                            Text(subtitleText)
                                .font(.custom("Inter18pt-Medium", size: 12))
                                .foregroundColor(subtitleColor)
                                .animation(.easeInOut(duration: 0.2), value: subtitleText)
                        }

                        Spacer()

                        if hasStories {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(hex: Constant.themeColor))
                                .rotationEffect(.degrees(isExpanded ? 0 : -90))
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                                .padding(.trailing, 4)
                        }

                        Button { showPrivacySheet = true } label: {
                            Image("setting")
                                .renderingMode(.template)
                                .resizable().scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: Constant.themeColor).opacity(0.15))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard hasStories else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { isExpanded.toggle() }
                    }

                    // My Stories cards
                    if hasStories {
                        HStack(alignment: .top, spacing: 0) {
                            // "+" add card — menu: Add Story | Promote Post
                            Menu {
                                Button { showPhotoPicker = true } label: {
                                    Label("Add Story", systemImage: "plus.circle")
                                }
                                Button { showPostAd = true } label: {
                                    Label("Promote Post", systemImage: "megaphone")
                                }
                            } label: {
                                ZStack {
                                    CachedAsyncImage(url: myProfileFullURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Image("inviteimg").resizable().scaledToFill()
                                    }
                                    .frame(width: 80, height: 120)
                                    .clipped()

                                    Color.black.opacity(0.35)

                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: Constant.themeColor))
                                            .frame(width: 28, height: 28)
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                                .frame(width: 80, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: Constant.themeColor), lineWidth: 1.5))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 16)
                            .padding(.vertical, 10)

                            // Story cards inside the horizontal scroll
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(uploadManager.myStories.enumerated()), id: \.element.id) { index, story in
                                        VStack(spacing: 6) {
                                            storyCard(story, width: 80, height: 120)
                                                .simultaneousGesture(TapGesture().onEnded {
                                                    queuePresentation = buildMyStoriesQueue(startingAt: index)
                                                })

                                            // Delete button — outside the card, below it
                                            Menu {
                                                Button(role: .destructive) {
                                                    uploadManager.deleteStory(id: story.id)
                                                } label: {
                                                    Label("Delete now", systemImage: "trash")
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .frame(width: 30, height: 30)
                                                    .background {
                                                        Circle()
                                                            .fill(.ultraThinMaterial)
                                                            .overlay(Circle().fill(Color.black.opacity(0.45)))
                                                    }
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                    }

                                    // Own ad cards — shown after story cards with "AD" badge
                                    ForEach(myOwnAds) { ad in
                                        VStack(spacing: 6) {
                                            adCard(ad, width: 80, height: 120)
                                                .simultaneousGesture(TapGesture().onEnded {
                                                    openMyAdPreview(ad)
                                                })
                                            // Delete button below card
                                            Menu {
                                                Button(role: .destructive) {
                                                    ApiService.shared.deleteAdvertisement(adId: ad.id) { success in
                                                        if success {
                                                            DispatchQueue.main.async {
                                                                myOwnAds.removeAll { $0.id == ad.id }
                                                            }
                                                        }
                                                    }
                                                } label: {
                                                    Label("Delete Ad", systemImage: "trash")
                                                }
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundColor(.white)
                                                    .frame(width: 30, height: 30)
                                                    .background {
                                                        Circle()
                                                            .fill(.ultraThinMaterial)
                                                            .overlay(Circle().fill(Color.black.opacity(0.45)))
                                                    }
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                    }

                                    if uploadManager.isUploading { uploadingCard }
                                }
                                .padding(.leading, 8)
                                .padding(.trailing, 16)
                                .padding(.vertical, 10)
                            }
                        }
                        .background(Color(hex: Constant.themeColor).opacity(0.07))
                        .frame(height: isExpanded ? nil : 0, alignment: .top)
                        .clipped()
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)

                    }
                    } // end My Stories container VStack
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 10)

                    // ── Hidden updates section ──────────────────────────
                    if !hiddenGroups.isEmpty {
                        VStack(spacing: 0) {
                            // Header row
                            HStack(spacing: 10) {
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color("gray3"))
                                    .frame(width: 50, height: 50)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Hidden updates")
                                        .font(.custom("Inter18pt-SemiBold", size: 15))
                                        .foregroundColor(Color("TextColor"))
                                    Text("\(hiddenGroups.count) \(hiddenGroups.count == 1 ? "contact" : "contacts")")
                                        .font(.custom("Inter18pt-Medium", size: 12))
                                        .foregroundColor(Color("gray3"))
                                }

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color("gray3"))
                                    .rotationEffect(.degrees(isHiddenSectionExpanded ? 0 : -90))
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHiddenSectionExpanded)
                                    .padding(.trailing, 4)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Color("gray3").opacity(0.12))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                    isHiddenSectionExpanded.toggle()
                                }
                            }

                            // Expanded: list each hidden contact with their story cards
                            if isHiddenSectionExpanded {
                                VStack(spacing: 0) {
                                    ForEach(hiddenGroups) { group in
                                        let isOpen = !collapsedHidden.contains(group.id)

                                        VStack(spacing: 0) {
                                            contactStoryRow(group, isOpen: isOpen, isHidden: true, isAllSeen: isGroupAllSeen(group))
                                                .background(Color("gray3").opacity(0.08))
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                        if isOpen { collapsedHidden.insert(group.id) }
                                                        else { collapsedHidden.remove(group.id) }
                                                    }
                                                }

                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 8) {
                                                    ForEach(Array(group.stories.enumerated()), id: \.element.id) { index, story in
                                                        storyCard(story, showDelete: false, isSeen: localSeenIds.contains(story.id), width: 80, height: 120)
                                                            .simultaneousGesture(TapGesture().onEnded {
                                                                storyViewerConfig = StoryViewerConfig(
                                                                    stories: group.stories,
                                                                    ownerUid: group.id,
                                                                    ownerName: group.fullName,
                                                                    ownerPhotoURL: group.photoURL,
                                                                    isOwnStory: false,
                                                                    startIndex: index
                                                                )
                                                            })
                                                    }
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 10)
                                            }
                                            .background(Color("gray3").opacity(0.04))
                                            .frame(height: isOpen ? nil : 0, alignment: .top)
                                            .clipped()
                                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOpen)
                                        }
                                    }
                                }
                                .background(Color("gray3").opacity(0.06))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 10)
                    }

                    // ── Visible contact stories (with ads interspersed) ──
                    ForEach(Array(filteredVisibleGroups.enumerated()), id: \.element.id) { idx, group in
                        let isOpen = !collapsedContacts.contains(group.id)

                        VStack(spacing: 0) {
                            contactStoryRow(group, isOpen: isOpen, isAllSeen: isGroupAllSeen(group))
                                .background(Color("gray3").opacity(0.12))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        if isOpen { collapsedContacts.insert(group.id) }
                                        else { collapsedContacts.remove(group.id) }
                                    }
                                }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(Array(group.stories.enumerated()), id: \.element.id) { index, story in
                                        storyCard(story, showDelete: false, isSeen: localSeenIds.contains(story.id), width: 80, height: 120)
                                            .simultaneousGesture(TapGesture().onEnded {
                                                openContactQueue(startingAt: group, storyIndex: index)
                                            })
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            .background(Color("gray3").opacity(0.06))
                            .frame(height: isOpen ? nil : 0, alignment: .top)
                            .clipped()
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOpen)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .padding(.horizontal, 10)
                    }
                }
            }
        }
        .background(Color("BackgroundColor"))
        .onAppear {
            uploadManager.fetchMyStories()
            uploadManager.fetchContactStories()
            fetchAds()
            fetchMyAds()
        }
        .onReceive(NotificationCenter.default.publisher(for: .adPosted)) { _ in
            fetchMyAds()
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
        .fullScreenCover(isPresented: $showPhotoPicker) {
            StoryPhotoPicker(
                onPost: { assets, caption in
                    uploadManager.uploadMedia(assets: assets, caption: caption)
                },
                onTextPost: { text, bgType, bgColor, gradStart, gradMid, gradEnd, fontIndex in
                    uploadManager.uploadText(textContent: text, bgType: bgType,
                                             bgColor: bgColor, gradStart: gradStart,
                                             gradMid: gradMid, gradEnd: gradEnd,
                                             fontIndex: fontIndex)
                }
            )
        }
        .fullScreenCover(item: $storyViewerConfig, onDismiss: {
            hiddenUids = Set(UserDefaults.standard.stringArray(forKey: "hiddenStoryUids") ?? [])
            localSeenIds = Set(UserDefaults.standard.stringArray(forKey: "localSeenStoryIds") ?? [])
        }) { config in
            StoryViewerView(
                stories: config.stories,
                ownerUid: config.ownerUid,
                ownerName: config.ownerName,
                ownerPhotoURL: config.ownerPhotoURL,
                isOwnStory: config.isOwnStory,
                startIndex: config.startIndex
            )
        }
        // Contact story queue — single unified viewer with one continuous progress bar
        .fullScreenCover(item: $queuePresentation, onDismiss: {
            hiddenUids   = Set(UserDefaults.standard.stringArray(forKey: "hiddenStoryUids") ?? [])
            localSeenIds = Set(UserDefaults.standard.stringArray(forKey: "localSeenStoryIds") ?? [])
        }) { pres in
            UnifiedStoryQueueView(
                segments: pres.segments,
                startIndex: pres.startIndex,
                shownAdIds: $shownAdIdsToday
            )
        }
        // Post new advertisement sheet
        .fullScreenCover(isPresented: $showPostAd) {
            PostAdvertiseView()
        }
        .fullScreenCover(item: $selectedContactGroup) { group in
            NavigationStack {
                UserInfoScreen(recUserId: group.id, recUserName: group.fullName)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button { selectedContactGroup = nil } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showMyUserInfo) {
            NavigationStack {
                UserInfoScreen(recUserId: Constant.SenderIdMy, recUserName: Constant.currentUserName)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button { showMyUserInfo = false } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPrivacySheet) {
            StoryPrivacySheet(isPresented: $showPrivacySheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert(item: $hideTargetGroup) { target in
            Alert(
                title: Text("Hide \(target.fullName)'s status updates?"),
                message: Text("You won't be notified of mentions from this contact. Their new status updates also won't appear at the top of the status list anymore."),
                primaryButton: .cancel(Text("Cancel")),
                secondaryButton: .destructive(Text("Hide")) {
                    hiddenUids.insert(target.id)
                    UserDefaults.standard.set(Array(hiddenUids), forKey: "hiddenStoryUids")
                }
            )
        }
    }

    // MARK: - Shared helpers

    @ViewBuilder
    private func profileImage(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Color(hex: Constant.themeColor), lineWidth: 2)
                .frame(width: size + 4, height: size + 4)
            CachedAsyncImage(url: myProfileFullURL) { image in
                image.resizable().scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
            } placeholder: {
                Image("inviteimg").resizable().scaledToFill()
                    .frame(width: size, height: size).clipShape(Circle())
            }
            .frame(width: size, height: size)
        }
        .frame(width: size + 4, height: size + 4)
    }

    private var plusBadge: some View {
        ZStack {
            Circle().fill(Color(hex: Constant.themeColor)).frame(width: 20, height: 20)
            Image(systemName: "plus").font(.system(size: 10, weight: .bold)).foregroundColor(.white)
        }
        .offset(x: 2, y: 2)
    }

    // MARK: - Story card

    @ViewBuilder
    private func storyCard(_ story: UserStory, showDelete: Bool = true, isSeen: Bool = false, width: CGFloat = 110, height: CGFloat = 170) -> some View {
        ZStack {
            // Background — thumbnail for media, colour/gradient for text
            Group {
                if story.storyType == "media", let url = story.firstThumbnailURL {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color(hex: Constant.themeColor).opacity(0.25)
                    }
                } else if story.storyType == "media" {
                    Color.black
                } else {
                    textStoryBackground(story)
                }
            }
            .frame(width: width, height: height)
            .clipped()

            // Play icon overlay for video stories
            if story.storyType == "media",
               story.mediaItems.first?.isVideo == true {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 28, height: 28)
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .offset(x: 1)
                }
            }


            // Text preview for text stories
            if story.storyType == "text", !story.textContent.isEmpty {
                Text(story.textContent)
                    .font(storyCardFont(story, size: showDelete ? 11 : 9))
                    .foregroundColor(storyCardTextColor(story))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 6)
                    .shadow(color: .black.opacity(0.6), radius: 2)
            }

            // Views bar — bottom gradient with eye + count horizontal, own stories only
            if showDelete {
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.65)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 36)
                    .overlay(
                        HStack(spacing: 3) {
                            Image(systemName: "eye.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1)
                            Text("\(story.viewsCount)")
                                .font(.custom("Inter18pt-SemiBold", size: 9))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 1)
                        }
                        .padding(.bottom, 5),
                        alignment: .bottom
                    )
                }
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: showDelete ? 14 : 10))
        .overlay {
            let corner: CGFloat = showDelete ? 14 : 10
            if showDelete {
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color(hex: Constant.themeColor), lineWidth: 1.5)
            } else if isSeen {
                RoundedRectangle(cornerRadius: corner)
                    .stroke(Color("gray3").opacity(0.35), lineWidth: 1.5)
            } else {
                RoundedRectangle(cornerRadius: corner)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(hex: Constant.themeColor),
                                Color(hex: "#FCAF45"),
                                Color(hex: "#FD1D1D"),
                                Color(hex: "#C13584"),
                                Color(hex: Constant.themeColor),
                            ],
                            center: .center
                        ),
                        lineWidth: 1.5
                    )
            }
        }
    }

    @ViewBuilder
    private func textStoryBackground(_ story: UserStory) -> some View {
        if story.bgType == "gradient", !story.gradientStart.isEmpty {
            // Reverse-lookup full 3-colour gradient — same logic as StoryViewerView
            let startLower = story.gradientStart.lowercased()
            let hexColors: [String] = storyGradients
                .first(where: { $0.hexColors[0].lowercased() == startLower })?
                .hexColors
                ?? [story.gradientStart, story.gradientMid, story.gradientEnd].filter { !$0.isEmpty }
            LinearGradient(
                colors: hexColors.map { Color(hex: $0) },
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        } else {
            // Strip ":fontIndex" suffix that may be appended to solid hex
            let hex = story.bgColor.split(separator: ":").first.map(String.init) ?? story.bgColor
            Color(hex: hex.isEmpty ? "#1a1a1a" : hex)
        }
    }

    /// Font matching the story's chosen royal-font style, at a small thumbnail size.
    private func storyCardFont(_ story: UserStory, size: CGFloat) -> Font {
        let fi: Int = {
            if story.bgType == "gradient" {
                // Font index encoded as suffix on gradient_end ("#HEX:N")
                let parts = story.gradientEnd.split(separator: ":", maxSplits: 1)
                if parts.count == 2, let n = Int(parts[1]) {
                    return max(0, min(n, storyRoyalFonts.count - 1))
                }
                return max(0, min(Int(story.bgColor) ?? story.fontIndex, storyRoyalFonts.count - 1))
            }
            let parts = story.bgColor.split(separator: ":", maxSplits: 1)
            let raw = parts.count == 2 ? (Int(parts[1]) ?? story.fontIndex) : story.fontIndex
            return max(0, min(raw, storyRoyalFonts.count - 1))
        }()
        let rf = storyRoyalFonts[fi]
        if let name = rf.customFontName { return .custom(name, size: size) }
        let f = Font.system(size: size, weight: rf.weight, design: rf.design)
        return rf.italic ? f.italic() : f
    }

    /// Text colour for thumbnail cards — dark only on Amber (#FFC107) solid background.
    private func storyCardTextColor(_ story: UserStory) -> Color {
        guard story.bgType == "solid" else { return .white }
        let hex = story.bgColor.split(separator: ":").first.map(String.init) ?? story.bgColor
        return hex.lowercased() == "#ffc107" ? .black : .white
    }

    // MARK: - Uploading placeholder card

    private var uploadingCard: some View {
        ZStack(alignment: .top) {
            Color(hex: Constant.themeColor).opacity(0.15)
            VStack(spacing: 6) {
                if uploadManager.progress > 0 {
                    Text("\(Int(uploadManager.progress * 100))%")
                        .font(.custom("Inter18pt-Medium", size: 12))
                        .foregroundColor(Color(hex: Constant.themeColor))
                }
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: Constant.themeColor)))
                    .scaleEffect(1.2)
                Spacer()
            }
            .padding(.top, 10)
        }
        .frame(width: 80, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: Constant.themeColor), lineWidth: 1.5))
    }

    // MARK: - Contact story row

    @ViewBuilder
    private func contactStoryRow(_ group: ContactStoryGroup, isOpen: Bool, isHidden: Bool = false, isAllSeen: Bool = false) -> some View {
        HStack(spacing: 10) {
            // Avatar with story ring (gradient = unseen, gray = seen)
            ZStack {
                if isAllSeen {
                    Circle()
                        .stroke(Color("gray3").opacity(0.4), lineWidth: 2.5)
                        .frame(width: 54, height: 54)
                } else {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: Constant.themeColor),
                                    Color(hex: "#FCAF45"),
                                    Color(hex: "#FD1D1D"),
                                    Color(hex: "#C13584"),
                                    Color(hex: Constant.themeColor),
                                ],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 54, height: 54)
                }
                CachedAsyncImage(url: group.photoURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image("inviteimg").resizable().scaledToFill()
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .opacity(isHidden ? 0.5 : 1)
            }
            .onTapGesture { selectedContactGroup = group }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.fullName)
                    .font(.custom("Inter18pt-SemiBold", size: 15))
                    .foregroundColor(Color("TextColor"))

                if let date = group.latestDate {
                    Text(relativeTime(from: date))
                        .font(.custom("Inter18pt-Medium", size: 12))
                        .foregroundColor(Color("gray3"))
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color("gray3"))
                .rotationEffect(.degrees(isOpen ? 0 : -90))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOpen)
                .padding(.trailing, 4)

            // 3-dot menu button
            Menu {
                Button { selectedContactGroup = group } label: { Text("For Visible") }
                if isHidden {
                    Button {
                        hiddenUids.remove(group.id)
                        UserDefaults.standard.set(Array(hiddenUids), forKey: "hiddenStoryUids")
                    } label: {
                        Label("Unhide \(group.fullName)", systemImage: "eye")
                    }
                } else {
                    Button(role: .destructive) {
                        hideTargetGroup = group
                    } label: {
                        Text("Hide \(group.fullName)")
                    }
                }
            } label: {
                VStack(spacing: 3) {
                    Circle().fill(Color("menuPointColor")).frame(width: 4, height: 4)
                    Circle().fill(Color(hex: Constant.themeColor)).frame(width: 4, height: 4)
                    Circle().fill(Color(red: 0x9E/255, green: 0xA6/255, blue: 0xB9/255)).frame(width: 4, height: 4)
                }
                .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    // Relative time helper for contact rows
    private func relativeTime(from date: Date) -> String {
        let diff = now.timeIntervalSince(date)
        if diff < 60    { return "just now" }
        if diff < 3600  { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        return "\(Int(diff / 86400))d ago"
    }

    // MARK: - Ad fetch

    private func fetchAds() {
        let uid      = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        let dialCode = UserDefaults.standard.string(forKey: Constant.country_Code) ?? "+1"
        guard !uid.isEmpty else { print("📢 [fetchAds] uid empty, skipping"); return }

        let dialMap: [String: String] = [
            "+91": "India", "+1": "United States", "+44": "United Kingdom",
            "+61": "Australia", "+971": "UAE", "+92": "Pakistan",
            "+880": "Bangladesh", "+977": "Nepal"
        ]
        let country = dialMap[dialCode] ?? "India"

        print("📢 [fetchAds] calling API uid=\(uid) dialCode=\(dialCode) country=\(country)")

        ApiService.shared.fetchAdvertisements(uid: uid, country: country) { ads in
            print("📢 [fetchAds] API returned \(ads.count) ads")
            for ad in ads { print("📢 [fetchAds] ad id=\(ad.id) title=\(ad.title) mediaCount=\(ad.mediaURLs.count)") }
            DispatchQueue.main.async { self.loadedAds = ads }
        }
    }

    private func fetchMyAds() {
        let uid = UserDefaults.standard.string(forKey: Constant.UID_KEY) ?? ""
        guard !uid.isEmpty else { return }
        ApiService.shared.fetchMyAdvertisements(uid: uid) { ads in
            DispatchQueue.main.async { self.myOwnAds = ads }
        }
    }

    // MARK: - Queue builder
    // Produces a flat [FlatQueueSegment] where every story AND every ad image is its own
    // segment, so the unified viewer can show one continuous progress bar for all of them.

    private func buildContactQueue(startingAt targetGroup: ContactStoryGroup, storyIndex: Int) -> StoryQueuePresentation {
        let eligible = loadedAds.filter { !shownAdIdsToday.contains($0.id) }
        var segments: [FlatQueueSegment] = []
        var adSlot = 0
        var startSegmentIndex = 0

        for (i, group) in filteredVisibleGroups.enumerated() {
            // Record where this group starts; add storyIndex offset for the tapped group
            if group.id == targetGroup.id {
                startSegmentIndex = segments.count + storyIndex
            }
            // One segment per story in the group
            for story in group.stories {
                segments.append(.story(story: story,
                                       ownerUid: group.id,
                                       ownerName: group.fullName,
                                       ownerPhotoURL: group.photoURL))
            }
            // Insert ad images between groups (never after the last group)
            let notLast = i + 1 < filteredVisibleGroups.count
            if notLast && !eligible.isEmpty && (i + 1) % adInterval == 0 && adSlot < eligible.count {
                let ad = eligible[adSlot]
                let count = max(1, ad.mediaURLs.count)
                for idx in 0..<count {
                    segments.append(.adMedia(ad: ad, mediaIndex: idx))
                }
                adSlot += 1
            }
        }

        return StoryQueuePresentation(segments: segments, startIndex: startSegmentIndex)
    }

    private func openContactQueue(startingAt group: ContactStoryGroup, storyIndex: Int) {
        queuePresentation = buildContactQueue(startingAt: group, storyIndex: storyIndex)
    }

    // Builds a flat queue for My Stories + My Own Ads so they share one unified progress bar.
    private func buildMyStoriesQueue(startingAt index: Int) -> StoryQueuePresentation {
        let myUid  = Constant.SenderIdMy
        let myName = Constant.currentUserName.isEmpty ? "My Stories" : Constant.currentUserName
        var segments: [FlatQueueSegment] = []
        for story in uploadManager.myStories {
            segments.append(.story(story: story,
                                   ownerUid: myUid,
                                   ownerName: myName,
                                   ownerPhotoURL: myProfileFullURL))
        }
        for ad in myOwnAds {
            let count = max(1, ad.mediaURLs.count)
            for idx in 0..<count {
                segments.append(.adMedia(ad: ad, mediaIndex: idx))
            }
        }
        let clamped = max(0, min(index, max(0, segments.count - 1)))
        return StoryQueuePresentation(segments: segments, startIndex: clamped)
    }

    // MARK: - Own ad helpers

    private func openMyAdPreview(_ ad: AdData) {
        let myUid  = Constant.SenderIdMy
        let myName = Constant.currentUserName.isEmpty ? "My Stories" : Constant.currentUserName
        var segments: [FlatQueueSegment] = []
        // Include own stories first so the queue is stories → ads (same as buildMyStoriesQueue)
        for story in uploadManager.myStories {
            segments.append(.story(story: story,
                                   ownerUid: myUid,
                                   ownerName: myName,
                                   ownerPhotoURL: myProfileFullURL))
        }
        var startIdx = segments.count   // default: first ad segment
        for myAd in myOwnAds {
            if myAd.id == ad.id { startIdx = segments.count }
            let count = max(1, myAd.mediaURLs.count)
            for idx in 0..<count {
                segments.append(.adMedia(ad: myAd, mediaIndex: idx))
            }
        }
        queuePresentation = StoryQueuePresentation(segments: segments, startIndex: startIdx)
    }

    // MARK: - Ad card (thumbnail for My Stories row)

    @ViewBuilder
    private func adCard(_ ad: AdData, width: CGFloat = 80, height: CGFloat = 120) -> some View {
        ZStack {
            if let url = ad.mediaURLs.first {
                CachedAsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Color(hex: Constant.themeColor).opacity(0.25)
                }
                .frame(width: width, height: height)
                .clipped()
            } else {
                LinearGradient(
                    colors: [Color(hex: "#00A3E9"), Color(hex: "#005080")],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: width, height: height)
                Text(ad.title)
                    .font(.custom("Inter18pt-SemiBold", size: 9))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 4)
            }

            // "AD" badge — bottom-center
            VStack {
                Spacer()
                Text("AD")
                    .font(.custom("Inter18pt-Bold", size: 7.5))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .padding(.bottom, 6)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: Constant.themeColor), lineWidth: 1.5)
        )
    }
}

// MARK: - Stories Privacy Sheet
private struct StoryPrivacySheet: View {
    @Binding var isPresented: Bool

    enum StoryShareMode { case myContacts, onlyWith }

    @State private var shareMode: StoryShareMode = .myContacts
    @State private var onlyWithIds: Set<String>  = []
    @State private var neverShareIds: Set<String> = []
    @State private var isLoading = false
    @State private var isSaving  = false
    @State private var hasLoadedPrivacy = false
    @State private var showEmptyOnlyWithAlert = false

    // Contact list — used to resolve uid → name + photo
    @StateObject private var chatVM = ChatViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Header ──
                ZStack {
                    Text("Stories Privacy")
                        .font(.custom("Inter18pt-SemiBold", size: 17))
                        .foregroundColor(Color("TextColor"))
                    HStack {
                        Button { isPresented = false } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color("TextColor"))
                                .frame(width: 32, height: 32)
                                .background(Color("gray3").opacity(0.15))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Button { savePrivacy() } label: {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: Constant.themeColor)))
                                    .frame(width: 56, height: 32)
                            } else {
                                Text("Save")
                                    .font(.custom("Inter18pt-SemiBold", size: 15))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                                    .background(Color(hex: Constant.themeColor))
                                    .clipShape(Capsule())
                            }
                        }
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: Constant.themeColor)))
                    Spacer()
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {

                            // ── Share with ──
                            Text("Share with")
                                .font(.custom("Inter18pt-Bold", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)

                            VStack(spacing: 0) {
                                // My contacts
                                Button { shareMode = .myContacts } label: {
                                    HStack(spacing: 14) {
                                        radioCircle(selected: shareMode == .myContacts)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("My contacts")
                                                .font(.custom("Inter18pt-SemiBold", size: 15))
                                                .foregroundColor(Color("TextColor"))
                                            Text("Share with all of your contacts")
                                                .font(.custom("Inter18pt-Regular", size: 13))
                                                .foregroundColor(Color("gray3"))
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 14)
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 58)

                                // Only share with row
                                HStack(spacing: 14) {
                                    Button { shareMode = .onlyWith } label: {
                                        radioCircle(selected: shareMode == .onlyWith)
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Only share with")
                                            .font(.custom("Inter18pt-SemiBold", size: 15))
                                            .foregroundColor(Color("TextColor"))
                                        Text(onlyWithIds.isEmpty
                                             ? "Only share with selected contacts"
                                             : "\(onlyWithIds.count) contact\(onlyWithIds.count == 1 ? "" : "s") selected")
                                            .font(.custom("Inter18pt-Regular", size: 13))
                                            .foregroundColor(onlyWithIds.isEmpty ? Color("gray3") : Color(hex: Constant.themeColor))
                                    }

                                    Spacer()

                                    NavigationLink {
                                        StoryOnlyShareWithView(preSelectedIds: onlyWithIds) { ids in
                                            onlyWithIds = ids.subtracting(neverShareIds)
                                            shareMode = .onlyWith
                                        }
                                    } label: {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Color("gray3").opacity(0.6))
                                            .frame(width: 36, height: 36)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 14)
                                .padding(.bottom, onlyWithIds.isEmpty ? 14 : 8)

                                // ── Included contacts chips ──
                                if !onlyWithIds.isEmpty {
                                    contactChips(ids: onlyWithIds, accentColor: Color(hex: Constant.themeColor), label: "Visible to")
                                        .padding(.bottom, 12)
                                }
                            }
                            .background(Color("gray3").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 16)

                            Text("Changes to your story privacy settings will not affect stories that you have already shared.")
                                .font(.custom("Inter18pt-Regular", size: 12))
                                .foregroundColor(Color("gray3"))
                                .padding(.horizontal, 20)
                                .padding(.top, 10)
                                .padding(.bottom, 24)

                            // ── Add exception ──
                            Text("Add exception")
                                .font(.custom("Inter18pt-Bold", size: 16))
                                .foregroundColor(Color("TextColor"))
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)

                            VStack(spacing: 0) {
                                NavigationLink {
                                    StoryOnlyShareWithView(
                                        screenTitle: "Never share with",
                                        preSelectedIds: neverShareIds
                                    ) { ids in
                                        neverShareIds = ids.subtracting(onlyWithIds)
                                    }
                                } label: {
                                    HStack {
                                        Text("Never share with")
                                            .font(.custom("Inter18pt-SemiBold", size: 15))
                                            .foregroundColor(Color("TextColor"))
                                        Spacer()
                                        HStack(spacing: 4) {
                                            Text(neverShareIds.isEmpty ? "Add users" : "\(neverShareIds.count) selected")
                                                .font(.custom("Inter18pt-Regular", size: 14))
                                                .foregroundColor(neverShareIds.isEmpty ? Color("gray3") : Color.red.opacity(0.85))
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(Color("gray3").opacity(0.6))
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 16)
                                    .padding(.bottom, neverShareIds.isEmpty ? 16 : 8)
                                }
                                .buttonStyle(.plain)

                                // ── Excluded contacts chips ──
                                if !neverShareIds.isEmpty {
                                    contactChips(ids: neverShareIds, accentColor: Color.red.opacity(0.8), label: "Hidden from")
                                        .padding(.bottom, 12)
                                }
                            }
                            .background(Color("gray3").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(Color("BackgroundColor"))
            .navigationBarHidden(true)
            .alert("No contacts selected", isPresented: $showEmptyOnlyWithAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please select at least one contact for \"Only share with\", or choose \"My contacts\".")
            }
            .onAppear {
                chatVM.fetchChatList(uid: Constant.SenderIdMy)
                if !hasLoadedPrivacy {
                    hasLoadedPrivacy = true
                    loadPrivacy()
                }
            }
        }
    }

    // MARK: - Contact chips strip

    @ViewBuilder
    private func contactChips(ids: Set<String>, accentColor: Color, label: String) -> some View {
        let contacts = chatVM.chatList.filter { ids.contains($0.uid) }
        if !contacts.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.custom("Inter18pt-Regular", size: 11))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(contacts) { contact in
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .strokeBorder(accentColor, lineWidth: 2)
                                        .frame(width: 38, height: 38)
                                    if let url = contactPhotoURL(contact) {
                                        CachedAsyncImage(url: url) { img in
                                            img.resizable().scaledToFill()
                                                .frame(width: 34, height: 34)
                                                .clipShape(Circle())
                                        } placeholder: {
                                            initialsCircle(contact.fullName, color: accentColor)
                                        }
                                    } else {
                                        initialsCircle(contact.fullName, color: accentColor)
                                    }
                                }
                                .frame(width: 38, height: 38)

                                Text(contact.fullName.components(separatedBy: " ").first ?? contact.fullName)
                                    .font(.custom("Inter18pt-Regular", size: 10))
                                    .foregroundColor(Color("TextColor"))
                                    .lineLimit(1)
                                    .frame(width: 44)
                            }
                        }
                        // If saved UIDs have no matching chat contact, show count badge for the remainder
                        let unknownCount = ids.count - contacts.count
                        if unknownCount > 0 {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(accentColor.opacity(0.15))
                                        .frame(width: 38, height: 38)
                                    Text("+\(unknownCount)")
                                        .font(.custom("Inter18pt-SemiBold", size: 11))
                                        .foregroundColor(accentColor)
                                }
                                Text("more")
                                    .font(.custom("Inter18pt-Regular", size: 10))
                                    .foregroundColor(Color("gray3"))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    @ViewBuilder
    private func initialsCircle(_ name: String, color: Color) -> some View {
        let initial = name.first.map { String($0).uppercased() } ?? "?"
        ZStack {
            Circle().fill(color.opacity(0.18)).frame(width: 34, height: 34)
            Text(initial)
                .font(.custom("Inter18pt-Bold", size: 13))
                .foregroundColor(color)
        }
    }

    private func contactPhotoURL(_ contact: UserActiveContactModel) -> URL? {
        guard !contact.photo.isEmpty else { return nil }
        let full = contact.photo.hasPrefix("http") ? contact.photo : Constant.baseURL + contact.photo
        return URL(string: full)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func radioCircle(selected: Bool) -> some View {
        ZStack {
            Circle()
                .fill(selected ? Color(hex: Constant.themeColor) : Color.clear)
                .frame(width: 24, height: 24)
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Circle()
                    .stroke(Color("gray3").opacity(0.5), lineWidth: 1.5)
                    .frame(width: 24, height: 24)
            }
        }
    }

    private func loadPrivacy() {
        isLoading = true
        ApiService.shared.fetchStoryPrivacy { settings in
            DispatchQueue.main.async {
                shareMode     = settings.visibilityType == "only_share_with" ? .onlyWith : .myContacts
                onlyWithIds   = Set(settings.shareWithUids)
                neverShareIds = Set(settings.neverShareUids)
                isLoading     = false
            }
        }
    }

    private func savePrivacy() {
        guard !(shareMode == .onlyWith && onlyWithIds.isEmpty) else {
            showEmptyOnlyWithAlert = true
            return
        }
        isSaving = true
        let visType = shareMode == .onlyWith ? "only_share_with" : "my_contacts"
        ApiService.shared.saveStoryPrivacy(
            visibilityType: visType,
            shareWithUids:  Array(onlyWithIds),
            neverShareUids: Array(neverShareIds)
        ) { success in
            DispatchQueue.main.async {
                isSaving = false
                if success { isPresented = false }
            }
        }
    }
}

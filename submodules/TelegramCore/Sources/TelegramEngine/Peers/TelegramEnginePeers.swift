import SwiftSignalKit
import Postbox
import SyncCore

public enum AddressNameValidationStatus: Equatable {
    case checking
    case invalidFormat(AddressNameFormatError)
    case availability(AddressNameAvailability)
}

public extension TelegramEngine {
    final class Peers {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func addressNameAvailability(domain: AddressNameDomain, name: String) -> Signal<AddressNameAvailability, NoError> {
            return _internal_addressNameAvailability(account: self.account, domain: domain, name: name)
        }

        public func updateAddressName(domain: AddressNameDomain, name: String?) -> Signal<Void, UpdateAddressNameError> {
            return _internal_updateAddressName(account: self.account, domain: domain, name: name)
        }

        public func checkPublicChannelCreationAvailability(location: Bool = false) -> Signal<Bool, NoError> {
            return _internal_checkPublicChannelCreationAvailability(account: self.account, location: location)
        }

        public func adminedPublicChannels(scope: AdminedPublicChannelsScope = .all) -> Signal<[Peer], NoError> {
            return _internal_adminedPublicChannels(account: self.account, scope: scope)
        }

        public func channelAddressNameAssignmentAvailability(peerId: PeerId?) -> Signal<ChannelAddressNameAssignmentAvailability, NoError> {
            return _internal_channelAddressNameAssignmentAvailability(account: self.account, peerId: peerId)
        }

        public func validateAddressNameInteractive(domain: AddressNameDomain, name: String) -> Signal<AddressNameValidationStatus, NoError> {
            if let error = _internal_checkAddressNameFormat(name) {
                return .single(.invalidFormat(error))
            } else {
                return .single(.checking)
                |> then(
                    self.addressNameAvailability(domain: domain, name: name)
                    |> delay(0.3, queue: Queue.concurrentDefaultQueue())
                    |> map { result -> AddressNameValidationStatus in
                        .availability(result)
                    }
                )
            }
        }

        public func findChannelById(channelId: Int32) -> Signal<Peer?, NoError> {
            return _internal_findChannelById(postbox: self.account.postbox, network: self.account.network, channelId: channelId)
        }

        public func supportPeerId() -> Signal<PeerId?, NoError> {
            return _internal_supportPeerId(account: self.account)
        }

        public func inactiveChannelList() -> Signal<[InactiveChannel], NoError> {
            return _internal_inactiveChannelList(network: self.account.network)
        }

        public func resolvePeerByName(name: String, ageLimit: Int32 = 2 * 60 * 60 * 24) -> Signal<PeerId?, NoError> {
            return _internal_resolvePeerByName(account: self.account, name: name, ageLimit: ageLimit)
        }

        public func searchPeers(query: String) -> Signal<([FoundPeer], [FoundPeer]), NoError> {
            return _internal_searchPeers(account: self.account, query: query)
        }

        public func updatedRemotePeer(peer: PeerReference) -> Signal<Peer, UpdatedRemotePeerError> {
            return _internal_updatedRemotePeer(postbox: self.account.postbox, network: self.account.network, peer: peer)
        }

        public func chatOnlineMembers(peerId: PeerId) -> Signal<Int32, NoError> {
            return _internal_chatOnlineMembers(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func convertGroupToSupergroup(peerId: PeerId) -> Signal<PeerId, ConvertGroupToSupergroupError> {
            return _internal_convertGroupToSupergroup(account: self.account, peerId: peerId)
        }

        public func createGroup(title: String, peerIds: [PeerId]) -> Signal<PeerId?, CreateGroupError> {
            return _internal_createGroup(account: self.account, title: title, peerIds: peerIds)
        }

        public func createSecretChat(peerId: PeerId) -> Signal<PeerId, CreateSecretChatError> {
            return _internal_createSecretChat(account: self.account, peerId: peerId)
        }

        public func setChatMessageAutoremoveTimeoutInteractively(peerId: PeerId, timeout: Int32?) -> Signal<Never, SetChatMessageAutoremoveTimeoutError> {
            if peerId.namespace == Namespaces.Peer.SecretChat {
                return _internal_setSecretChatMessageAutoremoveTimeoutInteractively(account: self.account, peerId: peerId, timeout: timeout)
                |> ignoreValues
                    |> castError(SetChatMessageAutoremoveTimeoutError.self)
            } else {
                return _internal_setChatMessageAutoremoveTimeoutInteractively(account: self.account, peerId: peerId, timeout: timeout)
            }
        }

        public func updateChannelSlowModeInteractively(peerId: PeerId, timeout: Int32?) -> Signal<Void, UpdateChannelSlowModeError> {
            return _internal_updateChannelSlowModeInteractively(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, timeout: timeout)
        }

        public func reportPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_reportPeer(account: self.account, peerId: peerId)
        }

        public func reportPeer(peerId: PeerId, reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeer(account: self.account, peerId: peerId, reason: reason, message: message)
        }

        public func reportPeerPhoto(peerId: PeerId, reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeerPhoto(account: self.account, peerId: peerId, reason: reason, message: message)
        }

        public func reportPeerMessages(messageIds: [MessageId], reason: ReportReason, message: String) -> Signal<Void, NoError> {
            return _internal_reportPeerMessages(account: account, messageIds: messageIds, reason: reason, message: message)
        }

        public func dismissPeerStatusOptions(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_dismissPeerStatusOptions(account: self.account, peerId: peerId)
        }

        public func reportRepliesMessage(messageId: MessageId, deleteMessage: Bool, deleteHistory: Bool, reportSpam: Bool) -> Signal<Never, NoError> {
            return _internal_reportRepliesMessage(account: self.account, messageId: messageId, deleteMessage: deleteMessage, deleteHistory: deleteHistory, reportSpam: reportSpam)
        }

        public func togglePeerMuted(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_togglePeerMuted(account: self.account, peerId: peerId)
        }

        public func updatePeerMuteSetting(peerId: PeerId, muteInterval: Int32?) -> Signal<Void, NoError> {
            return _internal_updatePeerMuteSetting(account: self.account, peerId: peerId, muteInterval: muteInterval)
        }

        public func updatePeerDisplayPreviewsSetting(peerId: PeerId, displayPreviews: PeerNotificationDisplayPreviews) -> Signal<Void, NoError> {
            return _internal_updatePeerDisplayPreviewsSetting(account: self.account, peerId: peerId, displayPreviews: displayPreviews)
        }

        public func updatePeerNotificationSoundInteractive(peerId: PeerId, sound: PeerMessageSound) -> Signal<Void, NoError> {
            return _internal_updatePeerNotificationSoundInteractive(account: self.account, peerId: peerId, sound: sound)
        }

        public func removeCustomNotificationSettings(peerIds: [PeerId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    TelegramCore.updatePeerNotificationSoundInteractive(transaction: transaction, peerId: peerId, sound: .default)
                    TelegramCore.updatePeerMuteSetting(transaction: transaction, peerId: peerId, muteInterval: nil)
                    TelegramCore.updatePeerDisplayPreviewsSetting(transaction: transaction, peerId: peerId, displayPreviews: .default)
                }
            }
            |> ignoreValues
        }

        public func channelAdminEventLog(peerId: PeerId) -> ChannelAdminEventLogContext {
            return ChannelAdminEventLogContext(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func updateChannelMemberBannedRights(peerId: PeerId, memberId: PeerId, rights: TelegramChatBannedRights?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant?, Bool), NoError> {
            return _internal_updateChannelMemberBannedRights(account: self.account, peerId: peerId, memberId: memberId, rights: rights)
        }

        public func updateDefaultChannelMemberBannedRights(peerId: PeerId, rights: TelegramChatBannedRights) -> Signal<Never, NoError> {
            return _internal_updateDefaultChannelMemberBannedRights(account: self.account, peerId: peerId, rights: rights)
        }

        public func createChannel(title: String, description: String?) -> Signal<PeerId, CreateChannelError> {
            return _internal_createChannel(account: self.account, title: title, description: description)
        }

        public func createSupergroup(title: String, description: String?, location: (latitude: Double, longitude: Double, address: String)? = nil, isForHistoryImport: Bool = false) -> Signal<PeerId, CreateChannelError> {
            return _internal_createSupergroup(account: self.account, title: title, description: description, location: location, isForHistoryImport: isForHistoryImport)
        }

        public func deleteChannel(peerId: PeerId) -> Signal<Void, DeleteChannelError> {
            return _internal_deleteChannel(account: self.account, peerId: peerId)
        }

        public func updateChannelHistoryAvailabilitySettingsInteractively(peerId: PeerId, historyAvailableForNewMembers: Bool) -> Signal<Void, ChannelHistoryAvailabilityError> {
            return _internal_updateChannelHistoryAvailabilitySettingsInteractively(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, peerId: peerId, historyAvailableForNewMembers: historyAvailableForNewMembers)
        }

        public func channelMembers(peerId: PeerId, category: ChannelMembersCategory = .recent(.all), offset: Int32 = 0, limit: Int32 = 64, hash: Int32 = 0) -> Signal<[RenderedChannelParticipant]?, NoError> {
            return _internal_channelMembers(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, peerId: peerId, category: category, offset: offset, limit: limit, hash: hash)
        }

        public func checkOwnershipTranfserAvailability(memberId: PeerId) -> Signal<Never, ChannelOwnershipTransferError> {
            return _internal_checkOwnershipTranfserAvailability(postbox: self.account.postbox, network: self.account.network, accountStateManager: self.account.stateManager, memberId: memberId)
        }

        public func updateChannelOwnership(channelId: PeerId, memberId: PeerId, password: String) -> Signal<[(ChannelParticipant?, RenderedChannelParticipant)], ChannelOwnershipTransferError> {
            return _internal_updateChannelOwnership(account: self.account, accountStateManager: self.account.stateManager, channelId: channelId, memberId: memberId, password: password)
        }

        public func searchGroupMembers(peerId: PeerId, query: String) -> Signal<[Peer], NoError> {
            return _internal_searchGroupMembers(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, peerId: peerId, query: query)
        }

        public func toggleShouldChannelMessagesSignatures(peerId: PeerId, enabled: Bool) -> Signal<Void, NoError> {
            return _internal_toggleShouldChannelMessagesSignatures(account: self.account, peerId: peerId, enabled: enabled)
        }

        public func requestPeerPhotos(peerId: PeerId) -> Signal<[TelegramPeerPhoto], NoError> {
            return _internal_requestPeerPhotos(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func updateGroupSpecificStickerset(peerId: PeerId, info: StickerPackCollectionInfo?) -> Signal<Void, UpdateGroupSpecificStickersetError> {
            return _internal_updateGroupSpecificStickerset(postbox: self.account.postbox, network: self.account.network, peerId: peerId, info: info)
        }

        public func joinChannel(peerId: PeerId, hash: String?) -> Signal<RenderedChannelParticipant?, JoinChannelError> {
            return _internal_joinChannel(account: self.account, peerId: peerId, hash: hash)
        }

        public func removePeerMember(peerId: PeerId, memberId: PeerId) -> Signal<Void, NoError> {
            return _internal_removePeerMember(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func availableGroupsForChannelDiscussion() -> Signal<[Peer], AvailableChannelDiscussionGroupError> {
            return _internal_availableGroupsForChannelDiscussion(postbox: self.account.postbox, network: self.account.network)
        }

        public func updateGroupDiscussionForChannel(channelId: PeerId?, groupId: PeerId?) -> Signal<Bool, ChannelDiscussionGroupError> {
            return _internal_updateGroupDiscussionForChannel(network: self.account.network, postbox: self.account.postbox, channelId: channelId, groupId: groupId)
        }

        public func peerCommands(id: PeerId) -> Signal<PeerCommands, NoError> {
            return _internal_peerCommands(account: self.account, id: id)
        }

        public func addGroupAdmin(peerId: PeerId, adminId: PeerId) -> Signal<Void, AddGroupAdminError> {
            return _internal_addGroupAdmin(account: self.account, peerId: peerId, adminId: adminId)
        }

        public func removeGroupAdmin(peerId: PeerId, adminId: PeerId) -> Signal<Void, RemoveGroupAdminError> {
            return _internal_removeGroupAdmin(account: self.account, peerId: peerId, adminId: adminId)
        }

        public func fetchChannelParticipant(peerId: PeerId, participantId: PeerId) -> Signal<ChannelParticipant?, NoError> {
            return _internal_fetchChannelParticipant(account: self.account, peerId: peerId, participantId: participantId)
        }

        public func updateChannelAdminRights(peerId: PeerId, adminId: PeerId, rights: TelegramChatAdminRights?, rank: String?) -> Signal<(ChannelParticipant?, RenderedChannelParticipant), UpdateChannelAdminRightsError> {
            return _internal_updateChannelAdminRights(account: self.account, peerId: peerId, adminId: adminId, rights: rights, rank: rank)
        }

        public func peerSpecificStickerPack(peerId: PeerId) -> Signal<PeerSpecificStickerPackData, NoError> {
            return _internal_peerSpecificStickerPack(postbox: self.account.postbox, network: self.account.network, peerId: peerId)
        }

        public func addRecentlySearchedPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_addRecentlySearchedPeer(postbox: self.account.postbox, peerId: peerId)
        }

        public func removeRecentlySearchedPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_removeRecentlySearchedPeer(postbox: self.account.postbox, peerId: peerId)
        }

        public func clearRecentlySearchedPeers() -> Signal<Void, NoError> {
            return _internal_clearRecentlySearchedPeers(postbox: self.account.postbox)
        }

        public func recentlySearchedPeers() -> Signal<[RecentlySearchedPeer], NoError> {
            return _internal_recentlySearchedPeers(postbox: self.account.postbox)
        }

        public func removePeerChat(peerId: PeerId, reportChatSpam: Bool, deleteGloballyIfPossible: Bool = false) -> Signal<Void, NoError> {
            return _internal_removePeerChat(account: self.account, peerId: peerId, reportChatSpam: reportChatSpam, deleteGloballyIfPossible: deleteGloballyIfPossible)
        }

        public func removePeerChats(peerIds: [PeerId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                for peerId in peerIds {
                    _internal_removePeerChat(account: self.account, transaction: transaction, mediaBox: self.account.postbox.mediaBox, peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: peerId.namespace == Namespaces.Peer.SecretChat)
                }
            }
            |> ignoreValues
        }

        public func terminateSecretChat(peerId: PeerId, requestRemoteHistoryRemoval: Bool) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_terminateSecretChat(transaction: transaction, peerId: peerId, requestRemoteHistoryRemoval: requestRemoteHistoryRemoval)
            }
            |> ignoreValues
        }

        public func addGroupMember(peerId: PeerId, memberId: PeerId) -> Signal<Void, AddGroupMemberError> {
            return _internal_addGroupMember(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func addChannelMember(peerId: PeerId, memberId: PeerId) -> Signal<(ChannelParticipant?, RenderedChannelParticipant), AddChannelMemberError> {
            return _internal_addChannelMember(account: self.account, peerId: peerId, memberId: memberId)
        }

        public func addChannelMembers(peerId: PeerId, memberIds: [PeerId]) -> Signal<Void, AddChannelMemberError> {
            return _internal_addChannelMembers(account: self.account, peerId: peerId, memberIds: memberIds)
        }

        public func recentPeers() -> Signal<RecentPeers, NoError> {
            return _internal_recentPeers(account: self.account)
        }

        public func managedUpdatedRecentPeers() -> Signal<Void, NoError> {
            return _internal_managedUpdatedRecentPeers(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network)
        }

        public func removeRecentPeer(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_removeRecentPeer(account: self.account, peerId: peerId)
        }

        public func updateRecentPeersEnabled(enabled: Bool) -> Signal<Void, NoError> {
            return _internal_updateRecentPeersEnabled(postbox: self.account.postbox, network: self.account.network, enabled: enabled)
        }

        public func addRecentlyUsedInlineBot(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_addRecentlyUsedInlineBot(postbox: self.account.postbox, peerId: peerId)
        }

        public func recentlyUsedInlineBots() -> Signal<[(Peer, Double)], NoError> {
            return _internal_recentlyUsedInlineBots(postbox: self.account.postbox)
        }

        public func removeRecentlyUsedInlineBot(peerId: PeerId) -> Signal<Void, NoError> {
            return _internal_removeRecentlyUsedInlineBot(account: self.account, peerId: peerId)
        }
    }
}

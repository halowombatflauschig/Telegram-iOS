import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import WebPBinding

private final class QuickReactionSetupControllerArguments {
    let context: AccountContext
    let selectItem: (String) -> Void
    
    init(
        context: AccountContext,
        selectItem: @escaping (String) -> Void
    ) {
        self.context = context
        self.selectItem = selectItem
    }
}

private enum QuickReactionSetupControllerSection: Int32 {
    case demo
    case items
}

private enum QuickReactionSetupControllerEntry: ItemListNodeEntry {
    enum StableId: Hashable {
        case demoHeader
        case demoMessage
        case demoDescription
        case itemsHeader
        case item(String)
    }
    
    case demoHeader(String)
    case demoMessage(wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, bubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, availableReactions: AvailableReactions?, reaction: String?)
    case demoDescription(String)
    case itemsHeader(String)
    case item(index: Int, value: String, image: UIImage?, text: String, isSelected: Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .demoHeader, .demoMessage, .demoDescription:
            return QuickReactionSetupControllerSection.demo.rawValue
        case .itemsHeader, .item:
            return QuickReactionSetupControllerSection.items.rawValue
        }
    }
    
    var stableId: StableId {
        switch self {
        case .demoHeader:
            return .demoHeader
        case .demoMessage:
            return .demoMessage
        case .demoDescription:
            return .demoDescription
        case .itemsHeader:
            return .itemsHeader
        case let .item(_, value, _, _, _):
            return .item(value)
        }
    }
    
    var sortId: Int {
        switch self {
        case .demoHeader:
            return 0
        case .demoMessage:
            return 1
        case .demoDescription:
            return 2
        case .itemsHeader:
            return 3
        case let .item(index, _, _, _, _):
            return 100 + index
        }
    }
    
    static func ==(lhs: QuickReactionSetupControllerEntry, rhs: QuickReactionSetupControllerEntry) -> Bool {
        switch lhs {
        case let .demoHeader(text):
            if case .demoHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .demoMessage(lhsWallpaper, lhsFontSize, lhsBubbleCorners, lhsDateTimeFormat, lhsNameDisplayOrder, lhsAvailableReactions, lhsReaction):
            if case let .demoMessage(rhsWallpaper, rhsFontSize, rhsBubbleCorners, rhsDateTimeFormat, rhsNameDisplayOrder, rhsAvailableReactions, rhsReaction) = rhs, lhsWallpaper == rhsWallpaper, lhsFontSize == rhsFontSize, lhsBubbleCorners == rhsBubbleCorners, lhsDateTimeFormat == rhsDateTimeFormat, lhsNameDisplayOrder == rhsNameDisplayOrder, lhsAvailableReactions == rhsAvailableReactions, lhsReaction == rhsReaction {
                return true
            } else {
                return false
            }
        case let .demoDescription(text):
            if case .demoDescription(text) = rhs {
                return true
            } else {
                return false
            }
        case let .itemsHeader(text):
            if case .itemsHeader(text) = rhs {
                return true
            } else {
                return false
            }
        case let .item(index, value, file, text, isEnabled):
            if case .item(index, value, file, text, isEnabled) = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: QuickReactionSetupControllerEntry, rhs: QuickReactionSetupControllerEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! QuickReactionSetupControllerArguments
        switch self {
        case let .demoHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .demoMessage(wallpaper, fontSize, chatBubbleCorners, dateTimeFormat, nameDisplayOrder, availableReactions, reaction):
            return ReactionChatPreviewItem(
                context: arguments.context,
                theme: presentationData.theme,
                strings: presentationData.strings,
                sectionId: self.section,
                fontSize: fontSize,
                chatBubbleCorners: chatBubbleCorners,
                wallpaper: wallpaper,
                dateTimeFormat: dateTimeFormat,
                nameDisplayOrder: nameDisplayOrder,
                availableReactions: availableReactions,
                reaction: reaction
            )
        case let .demoDescription(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .itemsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .item(_, value, image, text, isSelected):
            return ItemListCheckboxItem(
                presentationData: presentationData,
                icon: image,
                iconSize: image?.size.aspectFitted(CGSize(width: 30.0, height: 30.0)),
                title: text,
                style: .right,
                color: .accent,
                checked: isSelected,
                zeroSeparatorInsets: false,
                sectionId: self.section,
                action: {
                    arguments.selectItem(value)
                }
            )
        }
    }
}

private struct QuickReactionSetupControllerState: Equatable {
}

private func quickReactionSetupControllerEntries(
    presentationData: PresentationData,
    availableReactions: AvailableReactions?,
    images: [String: UIImage],
    reactionSettings: ReactionSettings
) -> [QuickReactionSetupControllerEntry] {
    var entries: [QuickReactionSetupControllerEntry] = []
    
    if let availableReactions = availableReactions {
        entries.append(.demoHeader(presentationData.strings.Settings_QuickReactionSetup_DemoHeader))
        entries.append(.demoMessage(
            wallpaper: presentationData.chatWallpaper,
            fontSize: presentationData.chatFontSize,
            bubbleCorners: presentationData.chatBubbleCorners,
            dateTimeFormat: presentationData.dateTimeFormat,
            nameDisplayOrder: presentationData.nameDisplayOrder,
            availableReactions: availableReactions,
            reaction: reactionSettings.quickReaction
        ))
        entries.append(.demoDescription(presentationData.strings.Settings_QuickReactionSetup_DemoInfo))
        
        entries.append(.itemsHeader(presentationData.strings.Settings_QuickReactionSetup_ReactionListHeader))
        var index = 0
        for availableReaction in availableReactions.reactions {
            if !availableReaction.isEnabled {
                continue
            }
            
            entries.append(.item(
                index: index,
                value: availableReaction.value,
                image: images[availableReaction.value],
                text: availableReaction.title,
                isSelected: reactionSettings.quickReaction == availableReaction.value
            ))
            index += 1
        }
    }
    
    return entries
}

public func quickReactionSetupController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil
) -> ViewController {
    let statePromise = ValuePromise(QuickReactionSetupControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: QuickReactionSetupControllerState())
    let updateState: ((QuickReactionSetupControllerState) -> QuickReactionSetupControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    let _ = dismissImpl
    
    let _ = updateState
    
    let actionsDisposable = DisposableSet()
    
    let arguments = QuickReactionSetupControllerArguments(
        context: context,
        selectItem: { reaction in            
            let _ = context.engine.stickers.updateQuickReaction(reaction: reaction).start()
        }
    )
    
    let settings = context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
    |> map { preferencesView -> ReactionSettings in
        let reactionSettings: ReactionSettings
        if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
            reactionSettings = value
        } else {
            reactionSettings = .default
        }
        return reactionSettings
    }
    
    let images: Signal<[String: UIImage], NoError> = context.engine.stickers.availableReactions()
    |> mapToSignal { availableReactions -> Signal<[String: UIImage], NoError> in
        var signals: [Signal<(String, UIImage?), NoError>] = []
        
        if let availableReactions = availableReactions {
            for availableReaction in availableReactions.reactions {
                if !availableReaction.isEnabled {
                    continue
                }
                
                let signal: Signal<(String, UIImage?), NoError> = context.account.postbox.mediaBox.resourceData(availableReaction.staticIcon.resource)
                |> distinctUntilChanged(isEqual: { lhs, rhs in
                    return lhs.complete == rhs.complete
                })
                |> map { data -> (String, UIImage?) in
                    guard data.complete else {
                        return (availableReaction.value, nil)
                    }
                    guard let dataValue = try? Data(contentsOf: URL(fileURLWithPath: data.path)) else {
                        return (availableReaction.value, nil)
                    }
                    guard let image = WebP.convert(fromWebP: dataValue) else {
                        return (availableReaction.value, nil)
                    }
                    return (availableReaction.value, image)
                }
                signals.append(signal)
            }
        }
        
        return combineLatest(queue: .mainQueue(), signals)
        |> map { values -> [String: UIImage] in
            var dict: [String: UIImage] = [:]
            for (key, image) in values {
                if let image = image {
                    dict[key] = image
                }
            }
            return dict
        }
    }
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        statePromise.get(),
        context.engine.stickers.availableReactions(),
        settings,
        images
    )
    |> deliverOnMainQueue
    |> map { presentationData, _, availableReactions, settings, images -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let title: String = presentationData.strings.Settings_QuickReactionSetup_Title
        
        let entries = quickReactionSetupControllerEntries(
            presentationData: presentationData,
            availableReactions: availableReactions,
            images: images,
            reactionSettings: settings
        )
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text(title),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: true
        )
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    controller.didScrollWithOffset = { [weak controller] offset, transition, _ in
        guard let controller = controller else {
            return
        }
        controller.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ReactionChatPreviewItemNode {
                itemNode.standaloneReactionAnimation?.addRelativeContentOffset(CGPoint(x: 0.0, y: offset), transition: transition)
            }
        }
    }
    
    dismissImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        controller.dismiss()
    }
    
    return controller
}


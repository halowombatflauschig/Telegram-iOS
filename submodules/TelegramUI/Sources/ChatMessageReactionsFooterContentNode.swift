import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import RadialStatusNode
import AnimatedCountLabelNode
import AnimatedAvatarSetNode
import ReactionButtonListComponent
import AccountContext
import WallpaperBackgroundNode

func canViewMessageReactionList(message: Message) -> Bool {
    var found = false
    for attribute in message.attributes {
        if let attribute = attribute as? ReactionsMessageAttribute {
            if !attribute.canViewList {
                return false
            }
            found = true
        }
    }
    
    if !found {
        return false
    }
    
    if let peer = message.peers[message.id.peerId] {
        if let channel = peer as? TelegramChannel {
            if case .broadcast = channel.info {
                return false
            } else {
                return true
            }
        } else if let _ = peer as? TelegramGroup {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}

final class MessageReactionButtonsNode: ASDisplayNode {
    enum DisplayType {
        case incoming
        case outgoing
        case freeform
    }
    
    enum DisplayAlignment {
        case left
        case right
    }
    
    private var bubbleBackgroundNode: WallpaperBubbleBackgroundNode?
    private let container: ReactionButtonsAsyncLayoutContainer
    private let backgroundMaskView: UIView
    private var backgroundMaskButtons: [String: UIView] = [:]
    
    var reactionSelected: ((String) -> Void)?
    var openReactionPreview: ((ContextGesture?, ContextExtractedContentContainingNode, String) -> Void)?
    
    override init() {
        self.container = ReactionButtonsAsyncLayoutContainer()
        self.backgroundMaskView = UIView()
        
        super.init()
    }
    
    func update() {
    }
    
    func prepareUpdate(
        context: AccountContext,
        presentationData: ChatPresentationData,
        presentationContext: ChatPresentationContext,
        availableReactions: AvailableReactions?,
        reactions: ReactionsMessageAttribute,
        message: Message,
        alignment: DisplayAlignment,
        constrainedWidth: CGFloat,
        type: DisplayType
    ) -> (proposedWidth: CGFloat, continueLayout: (CGFloat) -> (size: CGSize, apply: (ListViewItemUpdateAnimation) -> Void)) {
        let reactionColors: ReactionButtonComponent.Colors
        let themeColors: PresentationThemeBubbleColorComponents
        switch type {
        case .incoming:
            themeColors = bubbleColorComponents(theme: presentationData.theme.theme, incoming: true, wallpaper: !presentationData.theme.wallpaper.isEmpty)
            reactionColors = ReactionButtonComponent.Colors(
                deselectedBackground: themeColors.reactionInactiveBackground.argb,
                selectedBackground: themeColors.reactionActiveBackground.argb,
                deselectedForeground: themeColors.reactionInactiveForeground.argb,
                selectedForeground: themeColors.reactionActiveForeground.argb,
                extractedBackground: presentationData.theme.theme.contextMenu.backgroundColor.argb,
                extractedForeground:  presentationData.theme.theme.contextMenu.primaryColor.argb
            )
        case .outgoing:
            themeColors = bubbleColorComponents(theme: presentationData.theme.theme, incoming: false, wallpaper: !presentationData.theme.wallpaper.isEmpty)
            reactionColors = ReactionButtonComponent.Colors(
                deselectedBackground: themeColors.reactionInactiveBackground.argb,
                selectedBackground: themeColors.reactionActiveBackground.argb,
                deselectedForeground: themeColors.reactionInactiveForeground.argb,
                selectedForeground: themeColors.reactionActiveForeground.argb,
                extractedBackground: presentationData.theme.theme.contextMenu.backgroundColor.argb,
                extractedForeground:  presentationData.theme.theme.contextMenu.primaryColor.argb
            )
        case .freeform:
            if presentationData.theme.wallpaper.isEmpty {
                themeColors = presentationData.theme.theme.chat.message.freeform.withoutWallpaper
            } else {
                themeColors = presentationData.theme.theme.chat.message.freeform.withWallpaper
            }
            
            reactionColors = ReactionButtonComponent.Colors(
                deselectedBackground: selectReactionFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper).argb,
                selectedBackground: themeColors.reactionActiveBackground.argb,
                deselectedForeground: themeColors.reactionInactiveForeground.argb,
                selectedForeground: themeColors.reactionActiveForeground.argb,
                extractedBackground: presentationData.theme.theme.contextMenu.backgroundColor.argb,
                extractedForeground:  presentationData.theme.theme.contextMenu.primaryColor.argb
            )
        }
        
        var totalReactionCount: Int = 0
        for reaction in reactions.reactions {
            totalReactionCount += Int(reaction.count)
        }
        
        let reactionButtonsResult = self.container.update(
            context: context,
            action: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.reactionSelected?(value)
            },
            reactions: reactions.reactions.map { reaction in
                var iconFile: TelegramMediaFile?
                
                if let availableReactions = availableReactions {
                    for availableReaction in availableReactions.reactions {
                        if availableReaction.value == reaction.value {
                            iconFile = availableReaction.staticIcon
                            break
                        }
                    }
                }
                
                var peers: [EnginePeer] = []
                if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                } else {
                    for recentPeer in reactions.recentPeers {
                        if recentPeer.value == reaction.value {
                            if let peer = message.peers[recentPeer.peerId] {
                                peers.append(EnginePeer(peer))
                            }
                        }
                    }
                }
                
                if peers.count != Int(reaction.count) || totalReactionCount != reactions.recentPeers.count {
                    peers.removeAll()
                }
                
                return ReactionButtonsAsyncLayoutContainer.Reaction(
                    reaction: ReactionButtonComponent.Reaction(
                        value: reaction.value,
                        iconFile: iconFile
                    ),
                    count: Int(reaction.count),
                    peers: peers,
                    isSelected: reaction.isSelected
                )
            },
            colors: reactionColors,
            constrainedWidth: constrainedWidth
        )
        
        var reactionButtonsSize = CGSize()
        var currentRowWidth: CGFloat = 0.0
        for item in reactionButtonsResult.items {
            if currentRowWidth + item.size.width > constrainedWidth {
                reactionButtonsSize.width = max(reactionButtonsSize.width, currentRowWidth)
                if !reactionButtonsSize.height.isZero {
                    reactionButtonsSize.height += 6.0
                }
                reactionButtonsSize.height += item.size.height
                currentRowWidth = 0.0
            }
            
            if !currentRowWidth.isZero {
                currentRowWidth += 6.0
            }
            currentRowWidth += item.size.width
        }
        if !currentRowWidth.isZero && !reactionButtonsResult.items.isEmpty {
            reactionButtonsSize.width = max(reactionButtonsSize.width, currentRowWidth)
            if !reactionButtonsSize.height.isZero {
                reactionButtonsSize.height += 6.0
            }
            reactionButtonsSize.height += reactionButtonsResult.items[0].size.height
        }
        
        let topInset: CGFloat = 0.0
        let bottomInset: CGFloat = 2.0
        
        return (proposedWidth: reactionButtonsSize.width, continueLayout: { [weak self] boundingWidth in
            let size = CGSize(width: boundingWidth, height: topInset + reactionButtonsSize.height + bottomInset)
            return (size: size, apply: { animation in
                guard let strongSelf = self else {
                    return
                }
                
                let backgroundInsets: CGFloat = 10.0
                
                switch type {
                case .freeform:
                    if let backgroundNode = presentationContext.backgroundNode, backgroundNode.hasBubbleBackground(for: .free) {
                        let bubbleBackgroundFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: -backgroundInsets, dy: -backgroundInsets)
                        if let bubbleBackgroundNode = strongSelf.bubbleBackgroundNode {
                            animation.animator.updateFrame(layer: bubbleBackgroundNode.layer, frame: bubbleBackgroundFrame, completion: nil)
                            if let (rect, containerSize) = strongSelf.absoluteRect {
                                bubbleBackgroundNode.update(rect: rect, within: containerSize, transition: animation.transition)
                            }
                        } else if strongSelf.bubbleBackgroundNode == nil {
                            if let bubbleBackgroundNode = backgroundNode.makeBubbleBackground(for: .free) {
                                strongSelf.bubbleBackgroundNode = bubbleBackgroundNode
                                bubbleBackgroundNode.view.mask = strongSelf.backgroundMaskView
                                strongSelf.insertSubnode(bubbleBackgroundNode, at: 0)
                                bubbleBackgroundNode.frame = bubbleBackgroundFrame
                            }
                        }
                    } else {
                        if let bubbleBackgroundNode = strongSelf.bubbleBackgroundNode {
                            strongSelf.bubbleBackgroundNode = nil
                            bubbleBackgroundNode.removeFromSupernode()
                        }
                    }
                case .incoming, .outgoing:
                    if let bubbleBackgroundNode = strongSelf.bubbleBackgroundNode {
                        strongSelf.bubbleBackgroundNode = nil
                        bubbleBackgroundNode.removeFromSupernode()
                    }
                }
                
                var reactionButtonPosition: CGPoint
                switch alignment {
                case .left:
                    reactionButtonPosition = CGPoint(x: -1.0, y: topInset)
                case .right:
                    reactionButtonPosition = CGPoint(x: size.width + 1.0, y: topInset)
                }
                
                let reactionButtons = reactionButtonsResult.apply(animation)
                
                var validIds = Set<String>()
                for item in reactionButtons.items {
                    validIds.insert(item.value)
                    
                    switch alignment {
                    case .left:
                        if reactionButtonPosition.x + item.size.width > boundingWidth {
                            reactionButtonPosition.x = -1.0
                            reactionButtonPosition.y += item.size.height + 6.0
                        }
                    case .right:
                        if reactionButtonPosition.x - item.size.width < -1.0 {
                            reactionButtonPosition.x = size.width + 1.0
                            reactionButtonPosition.y += item.size.height + 6.0
                        }
                    }
                    
                    let itemFrame: CGRect
                    switch alignment {
                    case .left:
                        itemFrame = CGRect(origin: reactionButtonPosition, size: item.size)
                        reactionButtonPosition.x += item.size.width + 6.0
                    case .right:
                        itemFrame = CGRect(origin: CGPoint(x: reactionButtonPosition.x - item.size.width, y: reactionButtonPosition.y), size: item.size)
                        reactionButtonPosition.x -= item.size.width + 6.0
                    }
                    
                    let itemMaskFrame = itemFrame.offsetBy(dx: backgroundInsets, dy: backgroundInsets)
                    
                    let itemMaskView: UIView
                    if let current = strongSelf.backgroundMaskButtons[item.value] {
                        itemMaskView = current
                    } else {
                        itemMaskView = UIView()
                        itemMaskView.backgroundColor = .black
                        itemMaskView.clipsToBounds = true
                        itemMaskView.layer.cornerRadius = 15.0
                        strongSelf.backgroundMaskButtons[item.value] = itemMaskView
                    }
                    
                    if item.node.supernode == nil {
                        strongSelf.addSubnode(item.node)
                        if animation.isAnimated {
                            item.node.layer.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                            item.node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                        item.node.frame = itemFrame
                        
                        let itemValue = item.value
                        let itemNode = item.node
                        item.node.isGestureEnabled = canViewMessageReactionList(message: message)
                        item.node.activated = { [weak itemNode] gesture, _ in
                            guard let strongSelf = self, let itemNode = itemNode else {
                                gesture.cancel()
                                return
                            }
                            strongSelf.openReactionPreview?(gesture, itemNode.containerNode, itemValue)
                        }
                        item.node.additionalActivationProgressLayer = itemMaskView.layer
                    } else {
                        animation.animator.updateFrame(layer: item.node.layer, frame: itemFrame, completion: nil)
                    }
                    
                    if itemMaskView.superview == nil {
                        strongSelf.backgroundMaskView.addSubview(itemMaskView)
                        if animation.isAnimated {
                            itemMaskView.layer.animateScale(from: 0.01, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                            itemMaskView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        }
                        itemMaskView.frame = itemMaskFrame
                    } else {
                        animation.animator.updateFrame(layer: itemMaskView.layer, frame: itemMaskFrame, completion: nil)
                    }
                }
                
                var removeMaskIds: [String] = []
                for (id, view) in strongSelf.backgroundMaskButtons {
                    if !validIds.contains(id) {
                        removeMaskIds.append(id)
                        if animation.isAnimated {
                            view.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                            view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                                view?.removeFromSuperview()
                            })
                        } else {
                            view.removeFromSuperview()
                        }
                    }
                }
                for id in removeMaskIds {
                    strongSelf.backgroundMaskButtons.removeValue(forKey: id)
                }
                
                for node in reactionButtons.removedNodes {
                    if animation.isAnimated {
                        node.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                        node.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak node] _ in
                            node?.removeFromSupernode()
                        })
                    } else {
                        node.removeFromSupernode()
                    }
                }
            })
        })
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.absoluteRect = (rect, containerSize)
        
        if let bubbleBackgroundNode = self.bubbleBackgroundNode {
            bubbleBackgroundNode.update(rect: rect, within: containerSize, transition: transition)
        }
    }
    
    func update(rect: CGRect, within containerSize: CGSize, transition: CombinedTransition) {
        self.absoluteRect = (rect, containerSize)
        
        if let bubbleBackgroundNode = self.bubbleBackgroundNode {
            bubbleBackgroundNode.update(rect: rect, within: containerSize, transition: transition)
        }
    }
    
    func offset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if let bubbleBackgroundNode = self.bubbleBackgroundNode {
            bubbleBackgroundNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
    }
    
    func offsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
        if let bubbleBackgroundNode = self.bubbleBackgroundNode {
            bubbleBackgroundNode.offsetSpring(value: value, duration: duration, damping: damping)
        }
    }
    
    func reactionTargetView(value: String) -> UIView? {
        for (key, button) in self.container.buttons {
            if key == value {
                return button.iconView
            }
        }
        return nil
    }
    
    func animateIn(animation: ListViewItemUpdateAnimation) {
        for (_, button) in self.container.buttons {
            animation.animator.animateScale(layer: button.layer, from: 0.01, to: 1.0, completion: nil)
        }
    }
    
    func animateOut(animation: ListViewItemUpdateAnimation) {
        for (_, button) in self.container.buttons {
            animation.animator.updateScale(layer: button.layer, scale: 0.01, completion: nil)
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for (_, button) in self.container.buttons {
            if button.frame.contains(point) {
                if let result = button.hitTest(self.view.convert(point, to: button.view), with: event) {
                    return result
                }
            }
        }
        
        return nil
    }
}

final class ChatMessageReactionsFooterContentNode: ChatMessageBubbleContentNode {
    private let buttonsNode: MessageReactionButtonsNode
    
    required init() {
        self.buttonsNode = MessageReactionButtonsNode()
        
        super.init()
        
        self.addSubnode(self.buttonsNode)
        
        self.buttonsNode.reactionSelected = { [weak self] value in
            guard let strongSelf = self, let item = strongSelf.item else {
                return
            }
            item.controllerInteraction.updateMessageReaction(item.message, .reaction(value))
        }
        
        self.buttonsNode.openReactionPreview = { [weak self] gesture, sourceNode, value in
            guard let strongSelf = self, let item = strongSelf.item else {
                gesture?.cancel()
                return
            }
            
            item.controllerInteraction.openMessageReactionContextMenu(item.topMessage, sourceNode, gesture, value)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let buttonsNode = self.buttonsNode
        
        return { item, layoutConstants, preparePosition, _, constrainedSize in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            //let displaySeparator: Bool
            let topOffset: CGFloat
            if case let .linear(top, _) = preparePosition, case .Neighbour(_, .media, _) = top {
                //displaySeparator = false
                topOffset = 4.0
            } else {
                //displaySeparator = true
                topOffset = 0.0
            }
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let reactionsAttribute = mergedMessageReactions(attributes: item.message.attributes) ?? ReactionsMessageAttribute(canViewList: false, reactions: [], recentPeers: [])
                let buttonsUpdate = buttonsNode.prepareUpdate(
                    context: item.context,
                    presentationData: item.presentationData,
                    presentationContext: item.controllerInteraction.presentationContext,
                    availableReactions: item.associatedData.availableReactions, reactions: reactionsAttribute, message: item.message, alignment: .left, constrainedWidth: constrainedSize.width, type: item.message.effectivelyIncoming(item.context.account.peerId) ? .incoming : .outgoing)
                     
                return (layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right + buttonsUpdate.proposedWidth, { boundingWidth in
                    var boundingSize = CGSize()
                    
                    let buttonsSizeAndApply = buttonsUpdate.continueLayout(boundingWidth - (layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right))
                    
                    boundingSize = buttonsSizeAndApply.size
                    
                    boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                    boundingSize.height += topOffset + 2.0
                    
                    return (boundingSize, { [weak self] animation, synchronousLoad in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            animation.animator.updateFrame(layer: strongSelf.buttonsNode.layer, frame: CGRect(origin: CGPoint(x: layoutConstants.text.bubbleInsets.left, y: topOffset - 2.0), size: buttonsSizeAndApply.size), completion: nil)
                            buttonsSizeAndApply.apply(animation)
                            
                            let _ = synchronousLoad
                        }
                    })
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        self.buttonsNode.animateOut(animation: ListViewItemUpdateAnimation.System(duration: 0.25, transition: ControlledTransition(duration: 0.25, curve: .spring, interactive: false)))
    }
    
    override func animateInsertionIntoBubble(_ duration: Double) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
        self.layer.animatePosition(from: CGPoint(x: 0.0, y: -self.bounds.height / 2.0), to: CGPoint(), duration: duration, removeOnCompletion: true, additive: true)
    }
    
    override func animateRemovalFromBubble(_ duration: Double, completion: @escaping () -> Void) {
        self.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -self.bounds.height / 2.0), duration: duration, removeOnCompletion: false, additive: true)
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
            completion()
        })
        self.buttonsNode.animateOut(animation: ListViewItemUpdateAnimation.System(duration: 0.25, transition: ControlledTransition(duration: 0.25, curve: .spring, interactive: false)))
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if let result = self.buttonsNode.hitTest(self.view.convert(point, to: self.buttonsNode.view), with: nil), result !== self.buttonsNode.view {
            return .ignore
        }
        return .none
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.buttonsNode.hitTest(self.view.convert(point, to: self.buttonsNode.view), with: event), result !== self.buttonsNode.view {
            return result
        }
        return nil
    }
    
    override func reactionTargetView(value: String) -> UIView? {
        return self.buttonsNode.reactionTargetView(value: value)
    }
}

final class ChatMessageReactionButtonsNode: ASDisplayNode {
    final class Arguments {
        let context: AccountContext
        let presentationData: ChatPresentationData
        let presentationContext: ChatPresentationContext
        let availableReactions: AvailableReactions?
        let reactions: ReactionsMessageAttribute
        let message: Message
        let isIncoming: Bool
        let constrainedWidth: CGFloat
        
        init(
            context: AccountContext,
            presentationData: ChatPresentationData,
            presentationContext: ChatPresentationContext,
            availableReactions: AvailableReactions?,
            reactions: ReactionsMessageAttribute,
            message: Message,
            isIncoming: Bool,
            constrainedWidth: CGFloat
        ) {
            self.context = context
            self.presentationData = presentationData
            self.presentationContext = presentationContext
            self.availableReactions = availableReactions
            self.reactions = reactions
            self.message = message
            self.isIncoming = isIncoming
            self.constrainedWidth = constrainedWidth
        }
    }
    
    private let buttonsNode: MessageReactionButtonsNode
    
    var reactionSelected: ((String) -> Void)?
    var openReactionPreview: ((ContextGesture?, ContextExtractedContentContainingNode, String) -> Void)?
    
    override init() {
        self.buttonsNode = MessageReactionButtonsNode()
        
        super.init()
        
        self.addSubnode(self.buttonsNode)
        
        self.buttonsNode.reactionSelected = { [weak self] value in
            self?.reactionSelected?(value)
        }
        
        self.buttonsNode.openReactionPreview = { [weak self] gesture, sourceNode, value in
            self?.openReactionPreview?(gesture, sourceNode, value)
        }
    }
    
    class func asyncLayout(_ maybeNode: ChatMessageReactionButtonsNode?) -> (_ arguments: ChatMessageReactionButtonsNode.Arguments) -> (minWidth: CGFloat, layout: (CGFloat) -> (size: CGSize, apply: (_ animation: ListViewItemUpdateAnimation) -> ChatMessageReactionButtonsNode)) {
        return { arguments in
            let node = maybeNode ?? ChatMessageReactionButtonsNode()
            
            let buttonsUpdate = node.buttonsNode.prepareUpdate(
                context: arguments.context,
                presentationData: arguments.presentationData,
                presentationContext: arguments.presentationContext,
                availableReactions: arguments.availableReactions,
                reactions: arguments.reactions,
                message: arguments.message,
                alignment: arguments.isIncoming ? .left : .right,
                constrainedWidth: arguments.constrainedWidth,
                type: .freeform
            )
            
            return (buttonsUpdate.proposedWidth, { constrainedWidth in
                let buttonsResult = buttonsUpdate.continueLayout(constrainedWidth)
                
                return (CGSize(width: constrainedWidth, height: buttonsResult.size.height), { animation in
                    node.buttonsNode.frame = CGRect(origin: CGPoint(), size: buttonsResult.size)
                    buttonsResult.apply(animation)
                    
                    return node
                })
            })
        }
    }
    
    func animateIn(animation: ListViewItemUpdateAnimation) {
        self.buttonsNode.animateIn(animation: animation)
        self.buttonsNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    func animateOut(animation: ListViewItemUpdateAnimation, completion: @escaping () -> Void) {
        self.buttonsNode.animateOut(animation: animation)
        animation.animator.updateAlpha(layer: self.buttonsNode.layer, alpha: 0.0, completion: { _ in
            completion()
        })
        animation.animator.updateFrame(layer: self.buttonsNode.layer, frame: self.buttonsNode.layer.frame.offsetBy(dx: 0.0, dy: -self.buttonsNode.layer.bounds.height / 2.0), completion: nil)
    }
    
    func reactionTargetView(value: String) -> UIView? {
        return self.buttonsNode.reactionTargetView(value: value)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.buttonsNode.hitTest(self.view.convert(point, to: self.buttonsNode.view), with: event), result !== self.buttonsNode.view {
            return result
        }
        return nil
    }
    
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.buttonsNode.update(rect: rect, within: containerSize, transition: transition)
    }
    
    func update(rect: CGRect, within containerSize: CGSize, transition: CombinedTransition) {
        self.buttonsNode.update(rect: rect, within: containerSize, transition: transition)
    }
    
    func offset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        self.buttonsNode.offset(value: value, animationCurve: animationCurve, duration: duration)
    }
    
    func offsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
        self.buttonsNode.offsetSpring(value: value, duration: duration, damping: damping)
    }
}

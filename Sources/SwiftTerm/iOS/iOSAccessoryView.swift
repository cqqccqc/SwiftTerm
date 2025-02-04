//
//  iOSAccessoryView.swift
//  
//  Implements an inputAccessoryView for the iOS terminal for common operations
//
//  Created by Miguel de Icaza on 5/9/20.
//
#if os(iOS)

import Foundation
import UIKit

/**
 * This class provides an input accessory for the terminal on iOS, you can access this via the `inputAccessoryView`
 * property in the `TerminalView` and casting the result to `TerminalAccessory`.
 *
 * This class surfaces some state that the terminal might want to poke at, you should at least support the following
 * properties;
 * `controlModifer` should be set if the control key is pressed
 */
public class TerminalAccessory: UIInputView, UIInputViewAudioFeedback {
    /// This points to an instanace of the `TerminalView` where events are sent
    public weak var terminalView: TerminalView!
    weak var terminal: Terminal!
    var controlButton: UIButton!
    /// This tracks whether the "control" button is turned on or not
    public var controlModifier: Bool = false {
        didSet {
            controlButton.isSelected = controlModifier
        }
    }
    
    var touchButton: UIButton!
    var keyboardButton: UIButton!
    
    var views: [UIView] = []
    
    public init (frame: CGRect, inputViewStyle: UIInputView.Style, container: TerminalView)
    {
        self.terminalView = container
        self.terminal = terminalView.getTerminal()
        super.init (frame: frame, inputViewStyle: inputViewStyle)
        setupUI()
        allowsSelfSizing = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Override for UIInputViewAudioFeedback
    public var enableInputClicksWhenVisible: Bool { true }

    func clickAndSend (_ data: [UInt8])
    {
        UIDevice.current.playInputClick()
        terminalView.send (data)
    }
    
    @objc func esc (_ sender: AnyObject) { clickAndSend ([0x1b]) }
    @objc func tab (_ sender: AnyObject) { clickAndSend ([0x9]) }
    @objc func tilde (_ sender: AnyObject) { clickAndSend ([UInt8 (ascii: "~")]) }
    @objc func pipe (_ sender: AnyObject) { clickAndSend ([UInt8 (ascii: "|")]) }
    @objc func slash (_ sender: AnyObject) { clickAndSend ([UInt8 (ascii: "/")]) }
    @objc func dash (_ sender: AnyObject) { clickAndSend ([UInt8 (ascii: "-")]) }
    
    @objc
    func ctrl (_ sender: UIButton)
    {
        controlModifier.toggle()
    }

    // Controls the timer for auto-repeat
    var repeatCommand: (() -> ())? = nil
    var repeatTimer: Timer?
    
    func startTimerForKeypress (repeatKey: @escaping () -> ())
    {
        repeatKey ()
        repeatCommand = repeatKey
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            self.repeatCommand? ()
        }
    }
    
    @objc
    func cancelTimer ()
    {
        repeatTimer?.invalidate()
        repeatCommand = nil
        repeatTimer = nil
    }
    
    @objc func up (_ sender: UIButton)
    {
        startTimerForKeypress { self.terminalView.sendKeyUp () }
    }
    
    @objc func down (_ sender: UIButton)
    {
        startTimerForKeypress { self.terminalView.sendKeyDown () }
    }
    
    @objc func left (_ sender: UIButton)
    {
        startTimerForKeypress { self.terminalView.sendKeyLeft() }
    }
    
    @objc func right (_ sender: UIButton)
    {
        startTimerForKeypress { self.terminalView.sendKeyRight() }
    }


    @objc func toggleInputKeyboard (_ sender: UIButton) {
        guard let tv = terminalView else { return }
        let wasResponder = tv.isFirstResponder
        if wasResponder { _ = tv.resignFirstResponder() }

        if tv.inputView == nil {
            // Put actual code here:
            tv.inputView = UISlider (frame: CGRect (x: 0, y: 0, width: 100, height: 100))
        } else {
            tv.inputView = nil
        }
        if wasResponder { _ = tv.becomeFirstResponder() }

    }

    @objc func toggleTouch (_ sender: UIButton) {
        terminalView.allowMouseReporting.toggle()
        touchButton.isSelected = !terminalView.allowMouseReporting
    }

    /**
     * This method setups the internal data structures to setup the UI shown on the accessory view,
     * if you provide your own implementation, you are responsible for adding all the elements to the
     * this view, and flagging some of the public properties declared here.
     */
    public func setupUI ()
    {
        views.append(makeButton ("esc", #selector(esc)))
        controlButton = makeButton ("ctrl", #selector(ctrl))
        views.append(controlButton)
        views.append(makeButton ("tab", #selector(tab)))
        views.append(makeButton ("~", #selector(tilde)))
        views.append(makeButton ("|", #selector(pipe)))
        views.append(makeButton ("/", #selector(slash)))
        views.append(makeButton ("-", #selector(dash)))
        views.append(makeAutoRepeatButton ("arrow.left", #selector(left)))
        views.append(makeAutoRepeatButton ("arrow.up", #selector(up)))
        views.append(makeAutoRepeatButton ("arrow.down", #selector(down)))
        views.append(makeAutoRepeatButton ("arrow.right", #selector(right)))
        touchButton = makeButton ("", #selector(toggleTouch), icon: "hand.draw")
        touchButton.isSelected = !terminalView.allowMouseReporting
        views.append (touchButton)
        keyboardButton = makeButton ("", #selector(toggleInputKeyboard), icon: "keyboard.chevron.compact.down")
        views.append (keyboardButton)
        for view in views {
            let minSize: CGFloat = 24.0
            view.sizeToFit()
            if view.frame.width < minSize {
                let r = CGRect (origin: view.frame.origin, size: CGSize (width: minSize, height: view.frame.height))
                view.frame = r
            }
            addSubview(view)
        }
        layoutSubviews ()
    }
    
    public override func layoutSubviews() {
        
        var x: CGFloat = 2
        let dh = views.reduce (0) { max ($0, $1.frame.size.height )}
        for view in views {
            let size = view.frame.size
            view.frame = CGRect(x: x, y: 4, width: size.width, height: dh)
            x += size.width + 6
        }
        
        // Handle the last view separately
        if let last = views.last {
            if last.frame.maxY < frame.maxY {
                last.frame = CGRect (origin: CGPoint (x: frame.width - last.frame.width - 2, y: last.frame.minY), size: last.frame.size)
            }
        }
    }
    
    func makeAutoRepeatButton (_ iconName: String, _ action: Selector) -> UIButton
    {
        let b = makeButton ("", action, icon: iconName)
        b.addTarget(self, action: #selector(cancelTimer), for: .touchUpOutside)
        b.addTarget(self, action: #selector(cancelTimer), for: .touchCancel)
        b.addTarget(self, action: #selector(cancelTimer), for: .touchUpInside)
        return b
    }
    
    func makeButton (_ title: String, _ action: Selector, icon: String = "") -> UIButton
    {
        let b = UIButton.init(type: .roundedRect)
        styleButton (b)
        b.addTarget(self, action: action, for: .touchDown)
        b.setTitle(title, for: .normal)
        b.backgroundColor = UIColor.white
        if icon != "" {
            b.setImage(UIImage (systemName: icon, withConfiguration: UIImage.SymbolConfiguration (pointSize: 14)), for: .normal)
        }
        return b
    }
    
    // I am not committed to this style, this is just something quick to get going
    func styleButton (_ b: UIButton)
    {
        b.layer.cornerRadius = 5
        layer.masksToBounds = false
        layer.shadowOffset = CGSize(width: 0, height: 1.0)
        layer.shadowRadius = 0.0
        layer.shadowOpacity = 0.35
    }
}
#endif

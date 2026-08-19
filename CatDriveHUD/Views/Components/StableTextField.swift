import SwiftUI
import UIKit

/// UITextField-backed input used for destination entry.
///
/// Why this exists:
/// SwiftUI's TextField was losing first-responder status when the route model
/// published autocomplete/location updates and the Home card re-laid out.
/// UIKit owns first-responder state directly, so ordinary ObservableObject
/// redraws no longer collapse the keyboard.
struct StableTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isEnabled: Bool = true
    var returnKeyType: UIReturnKeyType = .next
    var onBeginEditing: () -> Void = {}
    var onSubmit: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.delegate = context.coordinator
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.textColor = UIColor(red: 0.09, green: 0.10, blue: 0.16, alpha: 1.0)
        field.tintColor = UIColor(red: 0.34, green: 0.28, blue: 0.96, alpha: 1.0)
        field.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .yes
        field.autocapitalizationType = .words
        field.spellCheckingType = .yes
        field.clearButtonMode = .never
        field.returnKeyType = returnKeyType
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        applyPlaceholder(to: field)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Refresh the coordinator's callbacks/binding without replacing the UITextField.
        // Most importantly: NEVER call resignFirstResponder() here.
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEnabled = isEnabled
        uiView.returnKeyType = returnKeyType
        applyPlaceholder(to: uiView)
    }

    private func applyPlaceholder(to field: UITextField) {
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: UIColor.secondaryLabel.withAlphaComponent(0.35),
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
            ]
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: StableTextField

        init(parent: StableTextField) {
            self.parent = parent
        }

        @objc func textChanged(_ sender: UITextField) {
            let newValue = sender.text ?? ""
            if parent.text != newValue {
                parent.text = newValue
            }
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onBeginEditing()
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onSubmit()
            // Keep responder lifecycle explicit and predictable.
            textField.resignFirstResponder()
            return false
        }
    }
}

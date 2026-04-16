import Foundation

struct Validators {
    static func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: email)
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= 6
    }
}


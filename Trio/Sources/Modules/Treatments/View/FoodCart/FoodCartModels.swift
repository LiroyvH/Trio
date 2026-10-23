import Foundation

struct FoodNutrition: Equatable {
    var carbs: Decimal
    var fat: Decimal
    var protein: Decimal

    static let zero = FoodNutrition(carbs: 0, fat: 0, protein: 0)

    static func + (lhs: FoodNutrition, rhs: FoodNutrition) -> FoodNutrition {
        FoodNutrition(
            carbs: lhs.carbs + rhs.carbs,
            fat: lhs.fat + rhs.fat,
            protein: lhs.protein + rhs.protein
        )
    }
}

enum FoodCalculator {
    /// Scales a value defined per `servingSize` to `amount` (30 g per 100 g, 250 g eaten -> 75)
    static func scale(_ valuePerServing: Decimal, servingSize: Decimal, amount: Decimal) -> Decimal {
        guard servingSize > 0, amount > 0 else { return 0 }
        return valuePerServing * amount / servingSize
    }

    static func nutrition(
        carbsPerServing: Decimal,
        fatPerServing: Decimal,
        proteinPerServing: Decimal,
        servingSize: Decimal,
        amount: Decimal
    ) -> FoodNutrition {
        FoodNutrition(
            carbs: scale(carbsPerServing, servingSize: servingSize, amount: amount),
            fat: scale(fatPerServing, servingSize: servingSize, amount: amount),
            protein: scale(proteinPerServing, servingSize: servingSize, amount: amount)
        )
    }

    /// Nearest whole number, halves round up (4.4 -> 4, 4.5 -> 5)
    static func roundToWholeGrams(_ value: Decimal) -> Decimal {
        var input = value
        var output = Decimal()
        NSDecimalRound(&output, &input, 0, .plain)
        return output
    }
}

/// Nutrition is a snapshot, so editing or deleting the food later doesn't affect the cart
struct FoodCartItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let unit: String
    let amount: Decimal
    let nutrition: FoodNutrition

    init(id: UUID = UUID(), name: String, unit: String, amount: Decimal, nutrition: FoodNutrition) {
        self.id = id
        self.name = name
        self.unit = unit
        self.amount = amount
        self.nutrition = nutrition
    }
}

struct FoodCart: Equatable {
    private(set) var items: [FoodCartItem] = []

    var isEmpty: Bool { items.isEmpty }

    mutating func add(_ item: FoodCartItem) {
        items.append(item)
    }

    mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    mutating func removeAll() {
        items.removeAll()
    }

    var total: FoodNutrition {
        items.reduce(FoodNutrition.zero) { $0 + $1.nutrition }
    }

    /// Rounded once on the total, not per item, to avoid accumulating rounding errors
    var roundedTotal: FoodNutrition {
        let exact = total
        return FoodNutrition(
            carbs: FoodCalculator.roundToWholeGrams(exact.carbs),
            fat: FoodCalculator.roundToWholeGrams(exact.fat),
            protein: FoodCalculator.roundToWholeGrams(exact.protein)
        )
    }

    /// e.g. "Spaghetti 250 g, Coca Cola 330 ml"
    func noteSummary(locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.locale = locale

        return items.map { item in
            let amount = formatter.string(from: item.amount as NSNumber) ?? "\(item.amount)"
            let unit = item.unit.trimmingCharacters(in: .whitespaces)
            return unit.isEmpty ? "\(item.name) \(amount)" : "\(item.name) \(amount) \(unit)"
        }.joined(separator: ", ")
    }

    /// Appends the summary to an existing note and caps the length with an ellipsis
    static func mergedNote(existing: String, summary: String, maxLength: Int = CarbsEntry.maxNoteLength) -> String {
        let trimmedExisting = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = trimmedExisting.isEmpty ? summary : "\(trimmedExisting), \(summary)"
        guard combined.count > maxLength, maxLength > 1 else { return combined }
        return String(combined.prefix(maxLength - 1)) + "…"
    }
}

extension FoodItemStored {
    func nutrition(forAmount amount: Decimal) -> FoodNutrition {
        FoodCalculator.nutrition(
            carbsPerServing: carbs?.decimalValue ?? 0,
            fatPerServing: fat?.decimalValue ?? 0,
            proteinPerServing: protein?.decimalValue ?? 0,
            servingSize: servingSize?.decimalValue ?? 0,
            amount: amount
        )
    }
}

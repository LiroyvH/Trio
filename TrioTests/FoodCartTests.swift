import Foundation
import Testing

@testable import Trio

@Suite("Food Cart Tests") struct FoodCartTests {
    private let nl = Locale(identifier: "nl_NL")
    private let us = Locale(identifier: "en_US")

    private func item(
        _ name: String,
        unit: String,
        amount: Decimal,
        carbs: Decimal,
        serving: Decimal,
        fat: Decimal = 0,
        protein: Decimal = 0
    ) -> FoodCartItem {
        FoodCartItem(
            name: name,
            unit: unit,
            amount: amount,
            nutrition: FoodCalculator.nutrition(
                carbsPerServing: carbs,
                fatPerServing: fat,
                proteinPerServing: protein,
                servingSize: serving,
                amount: amount
            )
        )
    }

    @Test("Spaghetti: 30 g carbs per 100 g, 250 g eaten is 75 g carbs") func scalesPerHundredGrams() {
        #expect(FoodCalculator.scale(30, servingSize: 100, amount: 250) == 75)
    }

    @Test("Coca Cola: 16 g carbs per 150 ml, 330 ml is 35.2 g carbs") func scalesWithDecimals() {
        #expect(FoodCalculator.scale(16, servingSize: 150, amount: 330) == Decimal(string: "35.2"))
    }

    @Test("Custom unit: 12 g carbs per cookie, 2.5 cookies is 30 g") func scalesCustomUnit() {
        #expect(FoodCalculator.scale(12, servingSize: 1, amount: Decimal(string: "2.5")!) == 30)
    }

    @Test("Invalid serving size or amount yields zero") func guardsInvalidInput() {
        #expect(FoodCalculator.scale(30, servingSize: 0, amount: 100) == 0)
        #expect(FoodCalculator.scale(30, servingSize: 100, amount: 0) == 0)
        #expect(FoodCalculator.scale(30, servingSize: 100, amount: -5) == 0)
    }

    @Test("Rounding goes to the nearest whole gram, halves up") func roundsToWholeGrams() {
        #expect(FoodCalculator.roundToWholeGrams(Decimal(string: "4.4")!) == 4)
        #expect(FoodCalculator.roundToWholeGrams(Decimal(string: "4.5")!) == 5)
        #expect(FoodCalculator.roundToWholeGrams(Decimal(string: "4.6")!) == 5)
        #expect(FoodCalculator.roundToWholeGrams(0) == 0)
    }

    @Test("Cart total sums unrounded values and rounds once") func totalRoundsOnce() {
        var cart = FoodCart()
        cart.add(item("A", unit: "g", amount: 100, carbs: Decimal(string: "4.4")!, serving: 100))
        cart.add(item("B", unit: "g", amount: 100, carbs: Decimal(string: "4.4")!, serving: 100))

        #expect(cart.total.carbs == Decimal(string: "8.8"))
        #expect(cart.roundedTotal.carbs == 9)
    }

    @Test("Cart combines carbs, fat and protein of several foods") func combinesMacros() {
        var cart = FoodCart()
        cart.add(item("Potatoes", unit: "g", amount: 200, carbs: 16, serving: 100, protein: 2))
        cart.add(item("Beef", unit: "g", amount: 250, carbs: 0, serving: 100, fat: 10, protein: 20))
        cart.add(item("Broccoli", unit: "g", amount: 300, carbs: 4, serving: 100, protein: Decimal(string: "2.8")!))

        let total = cart.roundedTotal
        #expect(total.carbs == 44)
        #expect(total.fat == 25)
        #expect(total.protein == 62)
    }

    @Test("Removing an item updates the total") func removesItem() {
        var cart = FoodCart()
        let first = item("A", unit: "g", amount: 100, carbs: 10, serving: 100)
        cart.add(first)
        cart.add(item("B", unit: "g", amount: 100, carbs: 20, serving: 100))

        cart.remove(id: first.id)

        #expect(cart.items.count == 1)
        #expect(cart.roundedTotal.carbs == 20)
    }

    @Test("Note summary lists amount and unit and follows the locale") func noteSummary() {
        var cart = FoodCart()
        cart.add(item("Spaghetti", unit: "g", amount: 250, carbs: 30, serving: 100))
        cart.add(item("Cookie", unit: "cookie", amount: Decimal(string: "2.5")!, carbs: 12, serving: 1))

        #expect(cart.noteSummary(locale: us) == "Spaghetti 250 g, Cookie 2.5 cookie")
        #expect(cart.noteSummary(locale: nl) == "Spaghetti 250 g, Cookie 2,5 cookie")
    }

    @Test("Merged note appends to an existing note") func mergedNoteAppends() {
        #expect(FoodCart.mergedNote(existing: "", summary: "Rice 100 g") == "Rice 100 g")
        #expect(FoodCart.mergedNote(existing: "Dinner", summary: "Rice 100 g") == "Dinner, Rice 100 g")
    }

    @Test("Merged note is capped with an ellipsis") func mergedNoteIsCapped() {
        let merged = FoodCart.mergedNote(existing: "", summary: String(repeating: "a", count: 50), maxLength: 20)

        #expect(merged.count == 20)
        #expect(merged.hasSuffix("…"))
    }
}

import SwiftUI

struct FoodAmountView: View {
    let food: FoodItemStored
    let showFatAndProtein: Bool
    let onAdd: (Decimal) -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppState.self) private var appState

    @State private var amount: Decimal

    init(
        food: FoodItemStored,
        showFatAndProtein: Bool,
        onAdd: @escaping (Decimal) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.food = food
        self.showFatAndProtein = showFatAndProtein
        self.onAdd = onAdd
        self.onCancel = onCancel
        _amount = State(initialValue: food.servingSize?.decimalValue ?? 0)
    }

    private var amountFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumIntegerDigits = 5
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private var resultFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }

    private var nutrition: FoodNutrition { food.nutrition(forAmount: amount) }
    private var canAdd: Bool { amount > 0 && (food.servingSize?.decimalValue ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Amount").fontWeight(.semibold)
                        Spacer()
                        TextFieldWithToolBar(
                            text: $amount,
                            placeholder: "0",
                            keyboardType: .decimalPad,
                            numberFormatter: amountFormatter,
                            initialFocus: true,
                            unitsText: food.unit ?? ""
                        )
                    }
                } header: {
                    Text(food.name ?? "")
                }
                .listRowBackground(Color.chart)

                Section {
                    resultRow(label: String(localized: "Carbs"), value: nutrition.carbs, color: .primary)
                    if showFatAndProtein {
                        resultRow(label: String(localized: "Fat"), value: nutrition.fat, color: .orange)
                        resultRow(label: String(localized: "Protein"), value: nutrition.protein, color: .red)
                    }
                } footer: {
                    Text("Totals are rounded to whole grams when added to Treatments.")
                }
                .listRowBackground(Color.chart)

                Button {
                    onAdd(amount)
                } label: {
                    Text("Add to Cart")
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!canAdd)
                .listRowBackground(canAdd ? Color(.systemBlue) : Color(.systemGray))
                .shadow(radius: 3)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle("Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onCancel() } label: { Text("Cancel") }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func resultRow(label: String, value: Decimal, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(color)
            Spacer()
            Text("\(resultFormatter.string(from: value as NSNumber) ?? "0") \(String(localized: "g", comment: "Units for carbs"))")
        }
    }
}

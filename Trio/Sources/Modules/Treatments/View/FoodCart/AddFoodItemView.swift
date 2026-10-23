import CoreData
import SwiftUI

struct AddFoodItemView: View {
    let food: FoodItemStored?
    let isFatProteinEnabled: Bool
    let onDone: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var moc
    @Environment(AppState.self) private var appState

    @State private var name: String
    @State private var unit: String
    @State private var servingSize: Decimal
    @State private var carbs: Decimal
    @State private var fat: Decimal
    @State private var protein: Decimal

    init(food: FoodItemStored?, isFatProteinEnabled: Bool, onDone: @escaping () -> Void) {
        self.food = food
        self.isFatProteinEnabled = isFatProteinEnabled
        self.onDone = onDone
        _name = State(initialValue: food?.name ?? "")
        _unit = State(initialValue: food?.unit ?? "g")
        _servingSize = State(initialValue: food?.servingSize?.decimalValue ?? 100)
        _carbs = State(initialValue: food?.carbs?.decimalValue ?? 0)
        _fat = State(initialValue: food?.fat?.decimalValue ?? 0)
        _protein = State(initialValue: food?.protein?.decimalValue ?? 0)
    }

    private var servingFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumIntegerDigits = 5
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private var nutrientFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumIntegerDigits = 4
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedUnit: String { unit.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isFormValid: Bool {
        !trimmedName.isEmpty && !trimmedUnit.isEmpty && servingSize > 0 && (carbs > 0 || fat > 0 || protein > 0)
    }

    private var servingDescription: String {
        let size = servingFormatter.string(from: servingSize as NSNumber) ?? "\(servingSize)"
        return "\(size) \(trimmedUnit)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextFieldWithToolBarString(
                        text: $name,
                        placeholder: String(localized: "Name Of Food"),
                        autocapitalizationType: .sentences,
                        maxLength: 40
                    )
                } header: {
                    Text(food == nil ? "New Food" : "Edit Food")
                }
                .listRowBackground(Color.chart)

                Section {
                    HStack {
                        Text("Serving Size")
                        Spacer()
                        TextFieldWithToolBar(
                            text: $servingSize,
                            placeholder: "100",
                            keyboardType: .decimalPad,
                            numberFormatter: servingFormatter
                        )
                    }
                    HStack {
                        Text("Unit")
                        Spacer()
                        TextFieldWithToolBarString(
                            text: $unit,
                            placeholder: String(localized: "g, ml, cookie..."),
                            maxLength: 12
                        )
                    }
                } header: {
                    Text("Serving")
                }
                .listRowBackground(Color.chart)

                Section {
                    nutrientRow(label: String(localized: "Carbs"), value: $carbs, color: .primary)
                    nutrientRow(label: String(localized: "Fat"), value: $fat, color: .orange)
                    nutrientRow(label: String(localized: "Protein"), value: $protein, color: .red)
                } header: {
                    Text("Nutrition per \(servingDescription)")
                } footer: {
                    // Fat and protein are always stored, but only sent to Treatments when enabled
                    if !isFatProteinEnabled {
                        Text("Fat and protein are saved, but only added to Treatments when 'Enable Fat and Protein Entries' is on.")
                    }
                }
                .listRowBackground(Color.chart)

                Button {
                    save()
                } label: {
                    Text("Save")
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(!isFormValid)
                .listRowBackground(isFormValid ? Color(.systemBlue) : Color(.systemGray))
                .shadow(radius: 3)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .scrollContentBackground(.hidden)
            .background(appState.trioBackgroundColor(for: colorScheme))
            .navigationTitle(food == nil ? "Add Food" : "Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { onDone() } label: { Text("Cancel") }
                }
            }
        }
    }

    private func nutrientRow(label: String, value: Binding<Decimal>, color: Color) -> some View {
        HStack {
            Text(label).foregroundStyle(color)
            Spacer()
            TextFieldWithToolBar(
                text: value,
                placeholder: "0",
                keyboardType: .decimalPad,
                numberFormatter: nutrientFormatter,
                unitsText: String(localized: "g", comment: "Units for carbs")
            )
        }
    }

    private func save() {
        let target = food ?? FoodItemStored(context: moc)
        if target.id == nil { target.id = UUID() }
        target.name = trimmedName
        target.unit = trimmedUnit
        target.servingSize = servingSize as NSDecimalNumber
        target.carbs = carbs as NSDecimalNumber
        target.fat = fat as NSDecimalNumber
        target.protein = protein as NSDecimalNumber

        do {
            try moc.save()
            onDone()
        } catch {
            debugPrint("\(DebuggingIdentifiers.failed) Failed to save food: \(error)")
            moc.rollback()
        }
    }
}

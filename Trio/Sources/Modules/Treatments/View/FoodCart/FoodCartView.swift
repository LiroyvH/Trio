import CoreData
import SwiftUI

private enum FoodEditorMode: Identifiable {
    case new
    case edit(FoodItemStored)

    var id: String {
        switch self {
        case .new: return "new"
        case let .edit(food): return food.objectID.uriRepresentation().absoluteString
        }
    }
}

struct FoodCartView: View {
    @Bindable var state: Treatments.StateModel

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @Environment(AppState.self) private var appState

    // Sorting and searching happen in Core Data, and rows are fetched in batches
    private static var foodRequest: NSFetchRequest<FoodItemStored> {
        let request = FoodItemStored.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(
            key: "name",
            ascending: true,
            selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))
        )]
        request.fetchBatchSize = 50
        return request
    }

    @FetchRequest(fetchRequest: FoodCartView.foodRequest) private var foods: FetchedResults<FoodItemStored>

    @State private var cart = FoodCart()
    @State private var searchText = ""
    @State private var foodToAdd: FoodItemStored?
    @State private var editorMode: FoodEditorMode?
    @State private var foodPendingDeletion: FoodItemStored?
    @FocusState private var isSearchFocused: Bool

    private var gramsFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }

    private var hasNutritionToAdd: Bool {
        let total = cart.roundedTotal
        return total.carbs > 0 || (state.useFPUconversion && (total.fat > 0 || total.protein > 0))
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                cartCard
                foodsCard
                if !isSearchFocused {
                    Text("Tap an item to add it to the shopping cart, tap \"New Food\" to add a new item to your database.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(appState.trioBackgroundColor(for: colorScheme).ignoresSafeArea())
            .navigationTitle("Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Text("Close") }
                }
            }
            .onChange(of: searchText) { _, newValue in
                let query = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                foods.nsPredicate = query.isEmpty ? nil : NSPredicate(format: "name CONTAINS[cd] %@", query)
            }
            .sheet(item: $foodToAdd) { food in
                FoodAmountView(
                    food: food,
                    showFatAndProtein: state.useFPUconversion,
                    onAdd: { amount in
                        addToCart(food, amount: amount)
                        foodToAdd = nil
                    },
                    onCancel: { foodToAdd = nil }
                )
            }
            .sheet(item: $editorMode) { mode in
                switch mode {
                case .new:
                    AddFoodItemView(food: nil, isFatProteinEnabled: state.useFPUconversion, onDone: { editorMode = nil })
                case let .edit(food):
                    AddFoodItemView(food: food, isFatProteinEnabled: state.useFPUconversion, onDone: { editorMode = nil })
                }
            }
            .alert(
                "Delete food?",
                isPresented: Binding(
                    get: { foodPendingDeletion != nil },
                    set: { if !$0 { foodPendingDeletion = nil } }
                ),
                presenting: foodPendingDeletion
            ) { food in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { delete(food) }
            } message: { food in
                Text("'\(food.name ?? "")' will be removed from your food database.")
            }
        }
    }

    // MARK: - Shopping cart

    private var cartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Shopping Cart", systemImage: "cart").font(.headline)
                Spacer()
                if !cart.isEmpty {
                    Button("Clear") { cart.removeAll() }.font(.subheadline)
                }
            }

            if cart.isEmpty {
                Text("Your cart is empty. Tap a food below to add it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if isSearchFocused {
                // Keep the cart compact while the keyboard is up so the food list stays usable
                Text("\(String(localized: "Total")) · \(String(localized: "Carbs")) \(gramsString(cart.roundedTotal.carbs))")
                    .font(.subheadline)
            } else {
                ViewThatFits(in: .vertical) {
                    cartRows
                    ScrollView { cartRows }
                }
                .frame(maxHeight: 170)

                Divider()
                totalsRow
                addToTreatmentsButton
            }
        }
        .padding(12)
        .background(Color.chart, in: cardShape)
    }

    private var cartRows: some View {
        VStack(spacing: 0) {
            ForEach(cart.items) { item in
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                        Text("\(amountString(item.amount)) \(item.unit)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(String(localized: "Carbs")) \(gramsString(item.nutrition.carbs))")
                        if state.useFPUconversion {
                            Text("\(String(localized: "Fat")) \(gramsString(item.nutrition.fat))").foregroundStyle(.orange)
                            Text("\(String(localized: "Protein")) \(gramsString(item.nutrition.protein))")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.footnote)
                    Button { cart.remove(id: item.id) } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Remove"))
                }
                .padding(.vertical, 6)

                if item.id != cart.items.last?.id {
                    Divider()
                }
            }
        }
    }

    private var totalsRow: some View {
        let total = cart.roundedTotal
        return VStack(spacing: 4) {
            HStack {
                Text("Carbs").fontWeight(.semibold)
                Spacer()
                Text(gramsString(total.carbs)).fontWeight(.semibold)
            }
            if state.useFPUconversion {
                HStack {
                    Text("Fat").foregroundStyle(.orange)
                    Spacer()
                    Text(gramsString(total.fat))
                }
                HStack {
                    Text("Protein").foregroundStyle(.red)
                    Spacer()
                    Text(gramsString(total.protein))
                }
            }
        }
    }

    private var addToTreatmentsButton: some View {
        Button {
            addCartToTreatments()
        } label: {
            Text("Add to Treatments")
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .background(
            hasNutritionToAdd ? Color(.systemBlue) : Color(.systemGray3),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .disabled(!hasNutritionToAdd)
    }

    // MARK: - Food database

    private var foodsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Food Database", systemImage: "fork.knife").font(.headline)
                Spacer()
                Button { editorMode = .new } label: {
                    HStack(spacing: 4) {
                        Text("New Food")
                        Image(systemName: "plus")
                    }
                }
                .font(.subheadline)
            }

            searchField

            List {
                if foods.isEmpty {
                    Group {
                        if searchText.isEmpty {
                            Text("No foods yet. Tap \"New Food\" to add one.")
                        } else {
                            Text("No matching foods.")
                        }
                    }
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                }
                ForEach(foods) { food in
                    Button { foodToAdd = food } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.name ?? "").foregroundStyle(.primary)
                            Text(perServingText(for: food))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            foodPendingDeletion = food
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            editorMode = .edit(food)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(12)
        .frame(maxHeight: .infinity)
        .background(Color.chart, in: cardShape)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search foods", text: $searchText)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { isSearchFocused = false }
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Clear"))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Actions

    private func addToCart(_ food: FoodItemStored, amount: Decimal) {
        cart.add(FoodCartItem(
            name: food.name ?? "",
            unit: food.unit ?? "",
            amount: amount,
            nutrition: food.nutrition(forAmount: amount)
        ))
    }

    private func addCartToTreatments() {
        let total = cart.roundedTotal
        state.carbs += total.carbs
        if state.useFPUconversion {
            state.fat += total.fat
            state.protein += total.protein
        }
        state.note = FoodCart.mergedNote(existing: state.note, summary: cart.noteSummary())
        dismiss()
    }

    private func delete(_ food: FoodItemStored) {
        moc.delete(food)
        do {
            try moc.save()
        } catch {
            debugPrint("\(DebuggingIdentifiers.failed) Failed to delete food: \(error)")
            moc.rollback()
        }
    }

    // MARK: - Formatting

    private func amountString(_ value: Decimal) -> String {
        gramsFormatter.string(from: value as NSNumber) ?? "\(value)"
    }

    private func gramsString(_ value: Decimal) -> String {
        "\(amountString(value)) \(String(localized: "g", comment: "Units for carbs"))"
    }

    private func perServingText(for food: FoodItemStored) -> String {
        let serving = "\(amountString(food.servingSize?.decimalValue ?? 0)) \(food.unit ?? "")"
        var parts = [String(localized: "Per \(serving)")]
        parts.append("\(String(localized: "Carbs")) \(gramsString(food.carbs?.decimalValue ?? 0))")
        if state.useFPUconversion {
            parts.append("\(String(localized: "Fat")) \(gramsString(food.fat?.decimalValue ?? 0))")
            parts.append("\(String(localized: "Protein")) \(gramsString(food.protein?.decimalValue ?? 0))")
        }
        return parts.joined(separator: " · ")
    }
}

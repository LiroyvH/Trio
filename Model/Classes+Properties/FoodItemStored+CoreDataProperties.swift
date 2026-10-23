import CoreData
import Foundation

public extension FoodItemStored {
    @nonobjc class func fetchRequest() -> NSFetchRequest<FoodItemStored> {
        NSFetchRequest<FoodItemStored>(entityName: "FoodItemStored")
    }

    // Nutrition values are grams per `servingSize` `unit`
    @NSManaged var carbs: NSDecimalNumber?
    @NSManaged var fat: NSDecimalNumber?
    @NSManaged var id: UUID?
    @NSManaged var name: String?
    @NSManaged var protein: NSDecimalNumber?
    @NSManaged var servingSize: NSDecimalNumber?
    // Free text, e.g. "g", "ml", "cookie"
    @NSManaged var unit: String?
}

extension FoodItemStored: Identifiable {}

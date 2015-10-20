import Foundation
import CoreData
import CoreLocation


/// MARK: - DASensor
class DASensor: NSManagedObject {

    /// MARK: - property
    @NSManaged var type: NSNumber
    @NSManaged var lat: NSNumber
    @NSManaged var long: NSNumber
    @NSManaged var weight: NSNumber
    @NSManaged var timestamp: NSDate


    /// MARK: - class method

    /**
     * GET sensor data from Heroku
     **/
    class func requestToGetNewSensors() {
        // sensor API
        if DASensor.hasData() { return }
        DASensorClient.sharedInstance.cancelGetSensor()
        DASensorClient.sharedInstance.getSensor(
            completionHandler: { (json) in
                if json["application_code"].intValue == 200 { DASensor.save(json: json["sensors"]) }
            }
        )
    }

    /**
     * fetch all data
     * @return [DASensor]
     **/
    class func fetchAll() -> [DASensor] {
        return DASensor.fetch(minimumCoordinate: CLLocationCoordinate2DMake(-180.0, -90.0), maximumCoordinate: CLLocationCoordinate2DMake(180.0, 90.0))
    }

    /**
     * fetch datas from coredata
     * @param minimumCoordinate CLLocationCoordinate2D
     * @param maximumCoordinate CLLocationCoordinate2D
     * @return [DASensor]
     */
    class func fetch(minimumCoordinate minimumCoordinate: CLLocationCoordinate2D, maximumCoordinate: CLLocationCoordinate2D) -> [DASensor] {
        let context = DACoreDataManager.sharedInstance.managedObjectContext

        // make fetch request
        let fetchRequest = NSFetchRequest()
        let entity = NSEntityDescription.entityForName("DASensor", inManagedObjectContext:context)
        fetchRequest.entity = entity
        fetchRequest.fetchBatchSize = 20
            // rect
        let predicaets = [
            NSPredicate(format: "(lat <= %@) AND (lat >= %@)", NSNumber(double: maximumCoordinate.latitude), NSNumber(double: minimumCoordinate.latitude)),
            NSPredicate(format: "(long <= %@) AND (long >= %@)", NSNumber(double: maximumCoordinate.longitude), NSNumber(double: minimumCoordinate.longitude)),
        ]
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicaets)
        fetchRequest.returnsObjectsAsFaults = false

        // return sensors
        var sensors: [DASensor]? = []
        do { sensors = try context.executeFetchRequest(fetchRequest) as? [DASensor] }
        catch { sensors = nil }
        if sensors == nil {
            NSUserDefaults().setObject("", forKey: DAUserDefaults.SensorYearMonth)
            NSUserDefaults().synchronize()
            return []
        }
        return sensors!
    }

    /**
     * save json datas to coredata
     * @param json JSON
     * [
     *   {
     *     "created_at": "2015-05-07T01:25:39.744Z",
     *     "id": 1,
     *     "lat": 37.792097317369965,
     *     "lng": -122.43528085596421,
     *     "type": 1,
     *     "timestamp": "2015-05-07T01:25:39.738Z",
     *     "updated_at": "2015-05-07T01:25:39.744Z",
     *     "weight": 57.23776223776224
     *   },
     *   ...
     * ]
     */
    class func save(json json: JSON) {
        if DASensor.hasData() { return }

        let sensorsJSON: [JSON]  = json.arrayValue
        let context = DACoreDataManager.sharedInstance.managedObjectContext

        let dateFormatter = NSDateFormatter()

        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        for sensorJSON in sensorsJSON {
            let timestamp = dateFormatter.dateFromString(sensorJSON["timestamp"].stringValue)
            if timestamp == nil { continue }

            let sensor = NSEntityDescription.insertNewObjectForEntityForName("DASensor", inManagedObjectContext: context) as! DASensor
            sensor.type = sensorJSON["type"].numberValue
            sensor.lat = sensorJSON["lat"].numberValue
            sensor.long = sensorJSON["lng"].numberValue
            sensor.weight = sensorJSON["weight"].numberValue
            sensor.timestamp = timestamp!
        }

        do { try context.save() }
        catch { return }

        if sensorsJSON.count > 0 {
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let currentYearMonth = dateFormatter.stringFromDate(NSDate())
            NSUserDefaults().setObject(currentYearMonth, forKey: DAUserDefaults.SensorYearMonth)
            NSUserDefaults().synchronize()
        }
    }

    /**
     * check if client needs to get new sensor data
     * @return Bool
     **/
    class func hasData() -> Bool {
        let sensorYearMonth = NSUserDefaults().stringForKey(DAUserDefaults.SensorYearMonth)

        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let currentYearMonth = dateFormatter.stringFromDate(NSDate())

        return (sensorYearMonth == currentYearMonth)
    }

}

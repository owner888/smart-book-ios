// CheckInService.swift - 签到服务（CloudKit 存储）

import Foundation
import CloudKit

@Observable
class CheckInService {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let recordType = "CheckInRecord"
    
    // UserDefaults 存储
    private let lastCheckInKey = "lastCheckInDate"
    private let streakKey = "checkInStreak"
    private let totalCheckInsKey = "totalCheckIns"
    
    var isTodayCheckedIn: Bool = false
    var currentStreak: Int = 0
    var totalCheckIns: Int = 0
    var lastCheckInDate: Date?
    
    init() {
        container = CKContainer(identifier: "iCloud.com.smartbook")
        privateDatabase = container.privateCloudDatabase
        loadLocalData()
        checkTodayStatus()
    }
    
    // MARK: - 本地存储
    
    private func loadLocalData() {
        lastCheckInDate = UserDefaults.standard.object(forKey: lastCheckInKey) as? Date
        currentStreak = UserDefaults.standard.integer(forKey: streakKey)
        totalCheckIns = UserDefaults.standard.integer(forKey: totalCheckInsKey)
    }
    
    private func saveLocalData() {
        if let date = lastCheckInDate {
            UserDefaults.standard.set(date, forKey: lastCheckInKey)
        }
        UserDefaults.standard.set(currentStreak, forKey: streakKey)
        UserDefaults.standard.set(totalCheckIns, forKey: totalCheckInsKey)
    }
    
    private func checkTodayStatus() {
        guard let lastDate = lastCheckInDate else {
            isTodayCheckedIn = false
            return
        }
        
        let calendar = Calendar.current
        isTodayCheckedIn = calendar.isDateInToday(lastDate)
    }
    
    // MARK: - 签到功能
    
    func checkIn() async throws {
        let calendar = Calendar.current
        let now = Date()
        
        if isTodayCheckedIn {
            return
        }
        
        if let lastDate = lastCheckInDate {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)
            if let yesterday = yesterday, calendar.isDate(lastDate, inSameDayAs: yesterday) {
                currentStreak += 1
            } else if !calendar.isDateInToday(lastDate) {
                currentStreak = 1
            }
        } else {
            currentStreak = 1
        }
        
        lastCheckInDate = now
        totalCheckIns += 1
        isTodayCheckedIn = true
        saveLocalData()
        
        saveToCloudKit(date: now, streak: currentStreak)
    }
    
    // MARK: - CloudKit 存储
    
    private func saveToCloudKit(date: Date, streak: Int) {
        let record = CKRecord(recordType: recordType)
        record["date"] = date
        record["streak"] = streak
        record["totalCheckIns"] = totalCheckIns
        
        privateDatabase.save(record) { _, error in
            if let error = error {
                Logger.error("CloudKit save error: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchFromCloudKit() async throws {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        let (results, _) = try await privateDatabase.records(matching: query, resultsLimit: 1)
        
        for (_, result) in results {
            if case .success(let record) = result {
                if let cloudDate = record["date"] as? Date,
                   let cloudStreak = record["streak"] as? Int,
                   let cloudTotal = record["totalCheckIns"] as? Int {
                    
                    if cloudDate > (lastCheckInDate ?? Date.distantPast) {
                        lastCheckInDate = cloudDate
                        currentStreak = cloudStreak
                        totalCheckIns = cloudTotal
                        checkTodayStatus()
                        saveLocalData()
                    }
                }
            }
        }
    }
    
    // MARK: - 统计信息
    
    var formattedStreak: String {
        if currentStreak == 0 {
            return "0"
        }
        return "\(currentStreak)"
    }
}

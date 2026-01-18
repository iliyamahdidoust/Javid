import Foundation

extension Date {
    // ✅ Compact time ago format (1m, 5h, 2d, etc.)
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .weekOfYear, .day, .hour, .minute, .second], from: self, to: now)
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1y" : "\(year)y"
        }
        if let month = components.month, month > 0 {
            return month == 1 ? "1mo" : "\(month)mo"
        }
        if let week = components.weekOfYear, week > 0 {
            return week == 1 ? "1w" : "\(week)w"
        }
        if let day = components.day, day > 0 {
            return day == 1 ? "1d" : "\(day)d"
        }
        if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1h" : "\(hour)h"
        }
        if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1m" : "\(minute)m"
        }
        return "now"
    }
    
    // ✅ Additional helper for full-text format (optional, for accessibility or settings)
    func timeAgoFull() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .weekOfYear, .day, .hour, .minute, .second], from: self, to: now)
        
        if let years = components.year, years > 0 {
            return years == 1 ? "1 year ago" : "\(years) years ago"
        }
        
        if let months = components.month, months > 0 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        }
        
        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }
        
        if let days = components.day, days > 0 {
            if days == 1 {
                return "Yesterday"
            } else {
                return "\(days) days ago"
            }
        }
        
        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
        
        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
        
        return "Just now"
    }
    
    // ✅ Format for chat date headers (Today, Yesterday, Jan 15, etc.)
    func chatDateString() -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else if calendar.isDate(self, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Monday, Tuesday, etc.
            return formatter.string(from: self)
        } else if calendar.isDate(self, equalTo: now, toGranularity: .year) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d" // Jan 15
            return formatter.string(from: self)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy" // Jan 15, 2024
            return formatter.string(from: self)
        }
    }
    
    // ✅ Time string for message timestamps (3:45 PM)
    func timeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
    
    // ✅ Full date and time (for detail views)
    func fullDateTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

import Foundation

/// Produces a CSV export of the user's dose history for sharing / backup.
public enum ExportService {

    /// Build a CSV string of every dose log, joined with its medicine.
    /// Columns: Medicine, Dosage, Status, Scheduled, Logged, Amount Taken, Source.
    /// Rows are sorted newest-logged first.
    public static func csv(medicines: [Medicine], logs: [DoseLog]) -> String {
        let medicineByID = Dictionary(
            medicines.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        let header = ["Medicine", "Dosage", "Status", "Scheduled", "Logged", "Amount Taken", "Source"]

        let sortedLogs = logs.sorted { $0.loggedAt > $1.loggedAt }

        var rows: [String] = [header.map(escape).joined(separator: ",")]

        for log in sortedLogs {
            let medicine = log.medicine ?? medicineByID[log.medicine?.id ?? UUID()]
            let name = medicine?.name ?? "Unknown"

            let dosageText: String
            if let amount = log.amountTaken, let medicine {
                dosageText = medicine.unit.formatted(amount)
            } else if let medicine {
                dosageText = medicine.dosageDescription
            } else {
                dosageText = ""
            }

            let amountText: String
            if let amount = log.amountTaken {
                amountText = formatAmount(amount)
            } else {
                amountText = ""
            }

            let row = [
                name,
                dosageText,
                log.status.label,
                formatter.string(from: log.scheduledTime),
                formatter.string(from: log.loggedAt),
                amountText,
                log.source.rawValue
            ]
            rows.append(row.map(escape).joined(separator: ","))
        }

        return rows.joined(separator: "\n")
    }

    // MARK: Helpers

    /// RFC-4180 style escaping: wrap in quotes if the field contains a comma,
    /// quote, or newline; double any embedded quotes.
    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        let doubled = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(doubled)\""
    }

    private static func formatAmount(_ amount: Double) -> String {
        amount == amount.rounded() ? String(Int(amount)) : String(format: "%g", amount)
    }
}

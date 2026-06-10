import Foundation
import SwiftData

/// Loads a representative sample portfolio so the whole feature set is explorable instantly.
enum DemoData {
    @MainActor
    static func load(into context: ModelContext) {
        // Apps
        let tmpo = AppEntity(name: "Tmpo", summary: "Tempo & metronome for musicians", status: .active, monthlyRevenue: 4_200, activeUsers: 18_400)
        tmpo.marketingNote = "ASO experiment running on 'metronome' keyword."
        let weather = AppEntity(name: "Weather.Co", summary: "Minimalist weather app", status: .maintenance, monthlyRevenue: 900, activeUsers: 6_100)
        context.insert(tmpo)
        context.insert(weather)

        // Job
        let job = JobEntity(title: "Senior Engineer", employer: "Northwind", status: .active, monthlyCompensation: 11_500, hoursPerWeek: 40)
        job.note = "Remote. Considering going full-time on the portfolio."
        context.insert(job)

        // Personal profile
        let personal = PersonalEntity(monthlyIncome: 0, monthlyExpenses: 7_200, currentSavings: 90_000, taxBracketEstimate: 0.24)
        personal.filingStatus = .single
        personal.stateTaxRate = 0.05
        personal.selfEmploymentPortion = 0.3
        context.insert(personal)

        // Balance sheet (assets + liabilities with APR/min payment)
        let sheet: [BalanceSheetItem] = [
            BalanceSheetItem(name: "Checking & savings", amount: 90_000, category: .cash),
            BalanceSheetItem(name: "Brokerage", amount: 140_000, category: .investments),
            BalanceSheetItem(name: "401(k)", amount: 165_000, category: .retirement),
            BalanceSheetItem(name: "Home", amount: 620_000, category: .realEstate),
            BalanceSheetItem(name: "Mortgage", amount: 410_000, category: .mortgage, apr: 0.062, minimumPayment: 2_450),
            BalanceSheetItem(name: "Visa", amount: 9_400, category: .creditCard, apr: 0.249, minimumPayment: 250),
            BalanceSheetItem(name: "Car loan", amount: 18_000, category: .autoLoan, apr: 0.069, minimumPayment: 420),
        ]
        sheet.forEach { context.insert($0) }

        // Goal
        let goal = GoalEntity(name: "12-month runway fund", summary: "Cover a year of expenses before going full-time", targetAmount: 90_000, currentAmount: 52_000)
        context.insert(goal)

        // Scenario with a per-entity override (quit the day job, grow Tmpo)
        let scenario = ScenarioEntity(name: "Go full-time on apps", summary: "Quit Northwind, Tmpo scales to $12K", monthsAhead: 24)
        scenario.entityOverrides = [
            .init(kind: .job, targetName: "Senior Engineer", included: false),
            .init(kind: .app, targetName: "Tmpo", included: true, monthlyValueOverride: 12_000),
        ]
        context.insert(scenario)

        // Analyzed deal (full analysis, saved)
        let deal = sampleDeal()
        let analysis = sampleAnalysis(for: deal)
        let dealEntity = DealEntity(businessName: deal.businessName)
        dealEntity.apply(analysis)
        dealEntity.status = .dueDiligence
        dealEntity.note = "Broker responsive. Seller retiring."
        context.insert(dealEntity)

        for (i, text) in DiligenceTemplate.items(for: deal.industry).prefix(6).enumerated() {
            let item = DiligenceItem(dealID: deal.id, text: text, isDone: i < 2, sortIndex: i)
            context.insert(item)
        }

        // Time tracking (drives the burnout score: ~56h/week)
        let cal = Calendar.current
        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            context.insert(TimeEntry(startedAt: day, minutes: 360, entityKind: "app", entityLabel: "Tmpo"))
            context.insert(TimeEntry(startedAt: day, minutes: 120, entityKind: "deal", entityLabel: "Cardinal Heating & Air"))
        }

        // Wellbeing check-ins (last 10 days)
        let energy = [3, 4, 3, 2, 4, 3, 4, 3, 2, 3]
        let stress = [4, 2, 3, 4, 2, 3, 2, 3, 4, 3]
        let sleep = [7.0, 8.0, 7.0, 6.0, 8.0, 7.0, 7.5, 6.0, 6.5, 7.5]
        let exercise = [30, 0, 45, 0, 30, 20, 0, 40, 0, 30]
        for offset in 0..<10 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            context.insert(WellbeingEntry(date: day, energy: energy[offset], stress: stress[offset], sleepHours: sleep[offset], exerciseMinutes: exercise[offset]))
        }

        // Habits with some history
        let deepWork = Habit(name: "Deep work (2h)", systemImage: "brain.head.profile", sortIndex: 0)
        let workout = Habit(name: "Workout", systemImage: "figure.run", sortIndex: 1)
        var dwKeys = Set<String>(), woKeys = Set<String>()
        for offset in 0..<12 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            if offset < 5 { dwKeys.insert(DayKey.string(from: day)) }
            if offset % 2 == 0 { woKeys.insert(DayKey.string(from: day)) }
        }
        deepWork.completionDayKeys = dwKeys
        workout.completionDayKeys = woKeys
        context.insert(deepWork)
        context.insert(workout)

        try? context.save()
    }

    // MARK: - Sample deal + analysis

    private static func sampleDeal() -> Deal {
        let addBacks = [
            AddBack(label: "Owner salary", amount: 130_000, category: .ownerSalary, credibility: 1.0),
            AddBack(label: "Owner truck", amount: 16_000, category: .personalVehicle, credibility: 0.6),
            AddBack(label: "One-time legal", amount: 28_000, category: .oneTimeExpense, credibility: 0.5),
            AddBack(label: "Family payroll", amount: 22_000, category: .familyPayroll, credibility: 0.4),
        ]
        return Deal(
            businessName: "Cardinal Heating & Air",
            industry: .hvac,
            location: "Columbus, OH",
            askingPrice: 1_350_000,
            reportedSDE: 430_000,
            grossRevenue: 2_100_000,
            addBacks: addBacks,
            loanTerms: LoanTerms(principal: 0, annualRate: 0.115, amortizationYears: 10),
            targetDSCR: 1.25
        )
    }

    private static func sampleAnalysis(for deal: Deal) -> Analysis {
        let loan = LoanTerms(principal: deal.askingPrice, annualRate: deal.loanTerms.annualRate, amortizationYears: deal.loanTerms.amortizationYears)
        let normalized = SDEEngine.normalize(reportedSDE: deal.reportedSDE, addBacks: deal.addBacks)
        let dscr = DSCREngine.dscr(normalizedSDE: normalized.normalized, loan: loan)
        let maxOffer = DSCREngine.maxOfferAt(targetDSCR: deal.targetDSCR, normalizedSDE: normalized.normalized, rate: deal.loanTerms.annualRate, amortizationYears: deal.loanTerms.amortizationYears)
        let multiple = MultipleEngine.read(askingPrice: deal.askingPrice, normalizedSDE: normalized.normalized, grossRevenue: deal.grossRevenue, category: deal.industry)
        let stress = SensitivityEngine.stressMatrix(normalizedSDE: normalized.normalized, loanTerms: loan)

        let verdict = Verdict(
            disposition: .worthPursuingWithConditions,
            headline: "A real business priced a touch ahead of itself — workable with a seller note.",
            oneLineSummary: "Normalized SDE holds up, but the asking multiple needs either a price concession or seller financing to pencil at your DSCR."
        )

        let review = AddBackReview(
            items: [
                AddBackComment(addBackID: deal.addBacks[0].id, label: "Owner salary", verdict: .accepted, commentary: "Standard, fully credible — a buyer will replace this role.", confidence: .high),
                AddBackComment(addBackID: deal.addBacks[1].id, label: "Owner truck", verdict: .discounted, commentary: "Partly personal use; haircut applied.", confidence: .medium),
                AddBackComment(addBackID: deal.addBacks[2].id, label: "One-time legal", verdict: .requiresVerification, commentary: "Get the invoices — 'one-time' items recur more than sellers admit.", confidence: .medium),
                AddBackComment(addBackID: deal.addBacks[3].id, label: "Family payroll", verdict: .discounted, commentary: "Confirm the work is genuinely non-essential before crediting it.", confidence: .low),
            ],
            overallNote: "Add-backs are reasonable but the soft ones are exactly where the seller is reaching."
        )

        let questions = BrokerQuestions(questions: [
            BrokerQuestion(topic: "Revenue", question: "What share of revenue is recurring service contracts vs. one-off installs?", why: "Contract density is what justifies the high end of the HVAC range.", confidence: .high),
            BrokerQuestion(topic: "Customers", question: "What's the revenue concentration of the top 10 accounts?", why: "Concentration above 25% is a real discount to the multiple.", confidence: .high),
            BrokerQuestion(topic: "Team", question: "How many licensed techs stay post-close, and on what terms?", why: "Owner-dependent trades businesses fall apart without the crew.", confidence: .medium),
        ])

        let changeMyMind = ChangeMyMind(conditions: [
            ChangeMyMindCondition(condition: "Seller carries a 15% note at 7%", impact: "DSCR clears 1.25 comfortably and the deal moves to 'pursue.'"),
            ChangeMyMindCondition(condition: "Price drops to the max-offer line", impact: "Removes the financing gap entirely."),
        ])

        return Analysis(
            deal: deal,
            normalized: normalized,
            primaryDSCR: dscr,
            maxOffer: maxOffer,
            multipleReading: multiple,
            stress: stress,
            verdict: verdict,
            addBackReview: review,
            brokerQuestions: questions,
            changeMyMind: changeMyMind,
            generatedAt: Date()
        )
    }
}

# frozen_string_literal: true

# Idempotent seed data for development/staging.
#
# Creates:
#   - 1 admin + 6 employee users (realistic names)
#   - 7 categories with descriptions
#   - 8 documents with real text content, chunked + marked ready
#     (chunks have placeholder zero-vector embeddings so VectorSearchService
#      stays happy; re-process via `EmbeddingJob.perform_later(chunk.id)`
#      once GEMINI_API_KEY is configured)
#   - 4 sample conversations with multi-turn messages + source citations
#
# Run: bin/rails db:seed
# Reset: bin/rails db:reset (drops + recreates + seeds)

require "stringio"

puts "🌱 Seeding database..."

# ---------------------------------------------------------------------------
# 1. USERS
# ---------------------------------------------------------------------------
puts "\n👤 Creating users..."

DEFAULT_PASSWORD = ENV.fetch("SEED_PASSWORD", "Password123!").freeze

admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("ADMIN_PASSWORD") do
  Rails.env.production? ? SecureRandom.alphanumeric(16) : "Admin123Dev456"
end

admin = User.find_or_initialize_by(email: admin_email).tap do |u|
  u.password = admin_password if u.new_record?
  u.role = :admin
  u.save!
end
puts "  ✓ Admin: #{admin.email}"

employees_data = [
  { email: "tanaka.hiroshi@example.com",    name: "Tanaka Hiroshi"    },
  { email: "suzuki.yuki@example.com",       name: "Suzuki Yuki"       },
  { email: "watanabe.aiko@example.com",     name: "Watanabe Aiko"     },
  { email: "yamamoto.kenji@example.com",    name: "Yamamoto Kenji"    },
  { email: "nakamura.sakura@example.com",   name: "Nakamura Sakura"   },
  { email: "kobayashi.takeshi@example.com", name: "Kobayashi Takeshi" }
]

employees = employees_data.map do |data|
  user = User.find_or_initialize_by(email: data[:email])
  user.password = DEFAULT_PASSWORD if user.new_record?
  user.role = :employee
  user.save!
  puts "  ✓ Employee: #{user.email}"
  user
end

# ---------------------------------------------------------------------------
# 2. CATEGORIES
# ---------------------------------------------------------------------------
puts "\n📂 Creating categories..."

categories_data = [
  { name: "Employee Handbook",
    description: "General company-wide policies, benefits, and conduct guidelines." },
  { name: "HR Policies",
    description: "Hiring, performance reviews, leave, compensation, and grievance procedures." },
  { name: "IT Support",
    description: "Hardware/software requests, VPN access, password resets, and troubleshooting." },
  { name: "Engineering",
    description: "Coding standards, deployment workflows, on-call rotations, and architecture decisions." },
  { name: "Security",
    description: "Access control, incident response, data classification, and acceptable use." },
  { name: "Finance",
    description: "Expense reimbursement, procurement, travel policy, and corporate cards." },
  { name: "Operations",
    description: "Facilities, office logistics, vendor management, and business continuity." }
]

categories = categories_data.to_h do |attrs|
  cat = Category.find_or_initialize_by(name: attrs[:name])
  cat.description = attrs[:description]
  cat.save!
  puts "  ✓ Category: #{cat.name}"
  [attrs[:name], cat]
end

# ---------------------------------------------------------------------------
# 3. DOCUMENTS + CHUNKS
# ---------------------------------------------------------------------------
puts "\n📄 Creating documents (with chunks, marked :ready)..."

documents_data = [
  {
    title: "Annual Leave & PTO Policy",
    filename: "annual-leave-policy.txt",
    category: "HR Policies",
    owner: admin,
    body: <<~TEXT
      ANNUAL LEAVE & PAID TIME OFF POLICY

      Eligibility
      All full-time employees are entitled to 20 days of paid annual leave per
      calendar year, accruing at 1.67 days per month. Part-time employees accrue
      leave on a pro-rated basis according to their contracted hours.

      Requesting Leave
      Submit leave requests through the HR portal at least 14 days in advance for
      planned absences. Requests of 5+ consecutive days require manager approval
      and a written handover plan covering ongoing projects, on-call coverage,
      and key stakeholder contacts.

      Carry-Over
      Up to 5 unused days may be carried into the following calendar year. Days
      beyond the carry-over cap are forfeited on January 1. Unused days are paid
      out at the prevailing daily rate upon termination of employment.

      Sick Leave
      Sick leave is separate from PTO. Employees receive 10 paid sick days per
      year. A doctor's note is required for absences of 3+ consecutive days.

      Bereavement & Compassionate Leave
      Up to 5 paid days are granted for the death of an immediate family member.
      Up to 2 paid days are granted for extended family. Additional unpaid leave
      may be approved on a case-by-case basis.
    TEXT
  },
  {
    title: "Remote Work & Hybrid Schedule Policy",
    filename: "remote-work-policy.txt",
    category: "HR Policies",
    owner: admin,
    body: <<~TEXT
      REMOTE WORK & HYBRID SCHEDULE POLICY

      Eligible employees may work remotely up to 3 days per week. The 2 in-office
      days must include at least one team-wide collaboration day (typically
      Tuesday or Wednesday) as set by each department head.

      Equipment
      The company provides a laptop, external monitor, keyboard, and chair
      stipend up to $500 for home-office setup. Stipends are claimed via the
      Finance portal with itemized receipts within 60 days of hire.

      Working Hours
      Core hours are 10:00-16:00 local time. Outside core hours, employees may
      shift their schedule with manager agreement, provided meeting attendance
      and customer commitments are maintained.

      Security Requirements
      Remote work requires connection through the corporate VPN, full-disk
      encryption on the work device, and an auto-locking screen set to 5 minutes
      or less. Personal devices may not access production systems.

      Exceptions
      Roles requiring physical presence (facilities, on-site IT, hardware
      engineering) are not eligible for remote work. Temporary remote-only
      arrangements for relocation or family circumstances require VP approval.
    TEXT
  },
  {
    title: "Expense Reimbursement Guide",
    filename: "expense-reimbursement.txt",
    category: "Finance",
    owner: admin,
    body: <<~TEXT
      EXPENSE REIMBURSEMENT GUIDE

      What's Reimbursable
      Business travel (flights, hotels, ground transport), client meals,
      conference fees, professional development courses pre-approved by your
      manager, and home-office equipment under the remote-work stipend.

      What's Not Reimbursable
      Personal expenses, alcohol outside of approved client entertainment,
      first-class flights (business class is allowed for flights over 6 hours),
      parking tickets, and gifts to government officials.

      Submitting an Expense
      Use the Expensify portal within 30 days of the expense. Attach a legible
      receipt for every line item over $25. Cash receipts and FX-converted
      receipts must include the original currency and the bank-rate used.

      Approval Flow
      Manager approves -> Finance reviews -> Reimbursement issued on the next
      payroll cycle (typically 7-10 business days). Expenses over $2,000
      additionally require Director approval.

      Corporate Card
      Employees in client-facing or travel-heavy roles may request a corporate
      card. Cardholders must reconcile transactions monthly; unreconciled
      charges over 60 days old are deducted from payroll.
    TEXT
  },
  {
    title: "VPN Access & Setup Guide",
    filename: "vpn-setup.txt",
    category: "IT Support",
    owner: admin,
    body: <<~TEXT
      VPN ACCESS & SETUP GUIDE

      Who Needs VPN
      Anyone accessing internal services (Jira, Confluence, staging environments,
      database admin tools, the Vault secrets manager) from outside the office
      network must connect via the corporate VPN.

      Installation
      1. Open Self-Service (macOS) or Software Center (Windows).
      2. Install "GlobalProtect VPN Client".
      3. Launch the app and enter portal address: vpn.company.internal
      4. Sign in with your corporate SSO credentials.
      5. Approve the MFA prompt on your registered device.

      Troubleshooting
      - "Cannot connect": Verify you're not already on the office Wi-Fi (VPN
        will refuse to connect when already on-network).
      - "Certificate expired": Renew the device cert via Self-Service ->
        "Renew VPN Certificate". Allow 5 minutes for propagation.
      - "MFA prompt not arriving": Open the authenticator app manually; the
        push notification can be delayed on weak cellular signal.

      Support
      File a ticket at help.company.internal or message #it-help on Slack.
      P1 outages affecting more than 10 users page the on-call IT engineer.
    TEXT
  },
  {
    title: "Password & Account Security Policy",
    filename: "password-security.txt",
    category: "Security",
    owner: admin,
    body: <<~TEXT
      PASSWORD & ACCOUNT SECURITY POLICY

      Password Requirements
      All passwords must be at least 14 characters, contain a mix of upper and
      lower case letters, numbers, and at least one symbol. Passwords must not
      reuse any of the previous 10 passwords or contain your name, username, or
      common patterns like "company" or "password".

      Multi-Factor Authentication
      MFA is required for all corporate accounts (SSO, GitHub, AWS, cloud
      consoles, VPN). Authenticator apps (1Password, Authy, Google Authenticator)
      are preferred. SMS-based MFA is permitted only as a fallback.

      Password Manager
      All employees receive a 1Password seat. Shared credentials must live in
      the team Vault - never in Slack, email, Notion, or code repositories.

      Compromised Credentials
      If you suspect a password has been compromised: (1) change it immediately,
      (2) revoke active sessions, (3) file an incident ticket at
      security.company.internal, and (4) notify your manager. Do not wait for
      confirmation - speed matters.

      Account Lockout
      Accounts are locked after 10 failed login attempts within 15 minutes.
      Unlock requires IT verification of identity via a video call.
    TEXT
  },
  {
    title: "Engineering On-Call Runbook",
    filename: "oncall-runbook.txt",
    category: "Engineering",
    owner: admin,
    body: <<~TEXT
      ENGINEERING ON-CALL RUNBOOK

      Rotation
      The on-call rotation covers 24/7 production support in 1-week shifts,
      Monday 10:00 to the following Monday 10:00 local time. Each engineer is
      expected to take roughly one shift per quarter. Swap requests must be
      logged in PagerDuty 48 hours in advance.

      Response Time SLAs
      - P1 (full outage / data loss): acknowledge within 5 minutes, mitigate
        within 30 minutes, restore within 2 hours.
      - P2 (degraded service / single-feature outage): acknowledge within 15
        minutes, mitigate within 2 hours.
      - P3 (minor issue, no customer impact): respond within one business day.

      Escalation Path
      Primary on-call -> Secondary on-call (after 10 min no-ack) -> Engineering
      Manager -> VP Engineering -> CTO. Customer-facing comms go through the
      Support lead, not directly from engineering.

      Tools
      - PagerDuty: pages and rotation schedule.
      - Datadog: dashboards (api-latency, db-saturation, queue-depth) and alerts.
      - Sentry: error tracking; check the on-call inbox first.
      - Runbooks: github.com/company/runbooks - one per service.

      Post-Incident
      Every P1 and P2 requires a blameless postmortem within 5 business days.
      Use the template at docs.company.internal/postmortems. Action items are
      tracked in Jira with "postmortem" label.
    TEXT
  },
  {
    title: "Code Review & Deployment Standards",
    filename: "code-review-standards.txt",
    category: "Engineering",
    owner: admin,
    body: <<~TEXT
      CODE REVIEW & DEPLOYMENT STANDARDS

      Pull Request Hygiene
      - One logical change per PR. Prefer < 400 lines diff.
      - PR description must include: what changed, why, how it was tested, and
        rollback steps.
      - Link the Jira ticket in the title (e.g., "ENG-1234: Add retry logic").
      - All CI checks must pass before merge.

      Review Requirements
      - At least one approval from a teammate familiar with the area.
      - Changes touching authentication, payments, or PII handling require
        approval from a Security Champion.
      - Database migrations require a second pair of eyes and a dry-run plan.

      Merge Strategy
      Squash-and-merge to main. The squashed commit message becomes the changelog
      entry, so write it like a release note (imperative mood, why-focused).

      Deployment
      Main branches auto-deploy to staging on merge. Production deploys are
      cut twice daily (10:00 and 15:00) by the release engineer. Hotfixes may
      be deployed off-schedule with on-call approval. Always monitor Datadog
      for 15 minutes post-deploy.

      Feature Flags
      Risky changes ship behind a LaunchDarkly flag with explicit cleanup date
      in the flag description. Stale flags are reaped quarterly.
    TEXT
  },
  {
    title: "Code of Conduct",
    filename: "code-of-conduct.txt",
    category: "Employee Handbook",
    owner: admin,
    body: <<~TEXT
      EMPLOYEE CODE OF CONDUCT

      Our Commitment
      We are committed to a workplace that is inclusive, respectful, and free
      from harassment and discrimination. This applies to all employees,
      contractors, vendors, and guests at company facilities and events.

      Expected Behavior
      - Treat colleagues with respect, regardless of role, background, or tenure.
      - Communicate clearly and assume good intent. Disagree with ideas, not
        people.
      - Protect confidential information about colleagues, customers, and the
        business.
      - Comply with all applicable laws and the company's published policies.

      Unacceptable Behavior
      Harassment of any kind (including based on race, gender, sexual
      orientation, religion, disability, or any protected characteristic),
      retaliation against good-faith reporters, dishonesty in business records,
      undisclosed conflicts of interest, and use of company resources for
      personal commercial activity.

      Reporting Concerns
      Multiple channels exist and you may choose any: (1) your manager, (2) HR
      partner, (3) anonymous hotline at ethics.company.internal, (4) any member
      of the Ethics Committee. Reports are investigated promptly and
      confidentially.

      Non-Retaliation
      The company prohibits retaliation against anyone reporting a concern in
      good faith or participating in an investigation. Retaliation is itself a
      violation of this Code and is treated as serious misconduct.
    TEXT
  }
]

documents_data.each do |data|
  doc = Document.find_by(filename: data[:filename])

  if doc
    puts "  • Document exists: #{doc.title}"
    next
  end

  doc = Document.new(
    title: data[:title],
    filename: data[:filename],
    content_type: "text/plain",
    category: categories[data[:category]],
    user: data[:owner],
    file_size: data[:body].bytesize
  )
  doc.file.attach(
    io: StringIO.new(data[:body]),
    filename: data[:filename],
    content_type: "text/plain"
  )
  # Skip validations: Marcel-sniff runs on upload; in seed-land we set content_type manually.
  doc.save!(validate: false)

  # Chunk the text (~512-char chunks, paragraph-aware) - mirrors TextChunkerService
  # output well enough for the UI to show real chunk counts.
  paragraphs = data[:body].split(/\n{2,}/).map(&:strip).reject(&:empty?)
  chunk_texts = []
  buffer = +""
  paragraphs.each do |para|
    if (buffer.length + para.length) > 512 && !buffer.empty?
      chunk_texts << buffer.strip
      buffer = +""
    end
    buffer << para << "\n\n"
  end
  chunk_texts << buffer.strip unless buffer.strip.empty?

  zero_vec = Array.new(768, 0.0)
  chunk_texts.each_with_index do |content, idx|
    attrs = {
      content: content,
      position: idx,
      metadata: { source: data[:filename], paragraph: idx }
    }
    # Embedding column may be `vector` or `text` depending on pgvector availability.
    attrs[:embedding] = zero_vec if DocumentChunk.pgvector_enabled?
    doc.document_chunks.create!(attrs)
  end

  doc.update_columns(
    status: Document.statuses[:ready],
    document_chunks_count: chunk_texts.length
  )
  puts "  ✓ Document: #{doc.title} (#{chunk_texts.length} chunks)"
end

# ---------------------------------------------------------------------------
# 4. CONVERSATIONS + MESSAGES
# ---------------------------------------------------------------------------
puts "\n💬 Creating sample conversations..."

conversations_data = [
  {
    user: employees[0],
    title: "How much PTO do I get?",
    turns: [
      { role: :user, content: "How many vacation days do I get per year?" },
      { role: :assistant, source_doc: "annual-leave-policy.txt", content: <<~MSG.strip }
        Full-time employees receive **20 days of paid annual leave per calendar
        year**, accruing at 1.67 days per month. Part-time employees accrue on a
        pro-rated basis based on contracted hours.

        A few things worth knowing:
        - Requests should be submitted via the HR portal at least 14 days in advance.
        - Up to 5 unused days carry over into the next calendar year; the rest are forfeited on January 1.
        - Sick leave (10 days/year) is tracked separately from PTO.

        Source: Annual Leave & PTO Policy
      MSG
    ]
  },
  {
    user: employees[1],
    title: "Setting up the VPN",
    turns: [
      { role: :user, content: "I'm working from home today and can't reach Jira. How do I set up the VPN?" },
      { role: :assistant, source_doc: "vpn-setup.txt", content: <<~MSG.strip }
        You'll need the **GlobalProtect VPN Client**. To get it set up:

        1. Open Self-Service (macOS) or Software Center (Windows).
        2. Install "GlobalProtect VPN Client".
        3. Launch it and enter the portal address: `vpn.company.internal`.
        4. Sign in with your corporate SSO credentials.
        5. Approve the MFA prompt on your registered device.

        A common gotcha: if you're already on the office Wi-Fi, the VPN will
        refuse to connect — disconnect from the office network first.

        Source: VPN Access & Setup Guide
      MSG
    ]
  },
  {
    user: employees[2],
    title: "Reimbursing a conference ticket",
    turns: [
      { role: :user, content: "I paid for a conference ticket out of pocket. What's the process to get reimbursed?" },
      { role: :assistant, source_doc: "expense-reimbursement.txt", content: <<~MSG.strip }
        Conference fees pre-approved by your manager are reimbursable. The flow:

        1. Submit through **Expensify** within 30 days of the expense.
        2. Attach a legible receipt (required for any line item over $25).
        3. Manager approves → Finance reviews → reimbursement on the next payroll cycle (typically 7–10 business days).

        Note: expenses over $2,000 also need Director approval, so flag it early if you're close to that threshold.

        Source: Expense Reimbursement Guide
      MSG
    ]
  },
  {
    user: employees[3],
    title: "On-call expectations",
    turns: [
      { role: :user, content: "I'm joining the on-call rotation next month. What are the SLAs I need to know?" },
      { role: :assistant, source_doc: "oncall-runbook.txt", content: <<~MSG.strip }
        Welcome to the rotation! The response-time SLAs are:

        - **P1** (full outage / data loss) — acknowledge in 5 min, mitigate in 30 min, restore in 2 hr.
        - **P2** (degraded service / single-feature outage) — acknowledge in 15 min, mitigate in 2 hr.
        - **P3** (minor, no customer impact) — respond within one business day.

        Rotations are 1-week shifts (Mon 10:00 → following Mon 10:00). If you need
        to swap, log it in PagerDuty at least 48 hours ahead. After any P1 or P2,
        a blameless postmortem is due within 5 business days.

        Source: Engineering On-Call Runbook
      MSG
    ],
    feedback_on_last: :positive
  }
]

conversations_data.each do |data|
  next if data[:user].conversations.exists?(title: data[:title])

  conv = data[:user].conversations.create!(title: data[:title])

  data[:turns].each_with_index do |turn, idx|
    msg = conv.messages.create!(
      role: turn[:role],
      content: turn[:content],
      status: :complete
    )

    if turn[:role] == :assistant && turn[:source_doc]
      source_doc = Document.find_by(filename: turn[:source_doc])
      source_doc&.document_chunks&.first(2)&.each_with_index do |chunk, i|
        MessageSource.create!(
          message: msg,
          document_chunk: chunk,
          relevance_score: 0.95 - (i * 0.07)
        )
      end
    end

    # Stagger timestamps so the UI shows realistic ordering
    msg.update_columns(created_at: idx.seconds.ago, updated_at: idx.seconds.ago)
  end

  if data[:feedback_on_last]
    conv.messages.where(role: :assistant).last&.update!(feedback: data[:feedback_on_last])
  end

  puts "  ✓ Conversation: #{conv.title} (#{data[:user].email})"
end

# ---------------------------------------------------------------------------
# DONE
# ---------------------------------------------------------------------------
puts "\n#{'=' * 60}"
puts "✅ Seed complete!"
puts "=" * 60
puts "Users:         #{User.count}  (#{User.admin.count} admin, #{User.employee.count} employee)"
puts "Categories:    #{Category.count}"
puts "Documents:     #{Document.count}  (#{Document.ready.count} ready)"
puts "Chunks:        #{DocumentChunk.count}"
puts "Conversations: #{Conversation.count}"
puts "Messages:      #{Message.count}"
puts "=" * 60
puts "Admin login (/admin/login):  #{admin_email} / #{Rails.env.development? ? admin_password : '[ADMIN_PASSWORD env var]'}"
puts "Employee login (/users/sign_in):"
employees.first(3).each { |e| puts "  #{e.email} / #{DEFAULT_PASSWORD}" }
puts "  ... and #{employees.length - 3} more (same password)"
puts "=" * 60
puts ""
puts "ℹ️  Chunk embeddings are zero-vector placeholders. To generate real"
puts "   embeddings with Gemini, set GEMINI_API_KEY and run:"
puts "     DocumentChunk.find_each { |c| EmbeddingJob.perform_later(c.id) }"
puts ""

# ⚖️ Clarity-Powered Court Orders Registry

A decentralized smart contract system for managing court orders and tracking compliance on the Stacks blockchain.

## 🚀 Features

- **📋 Court Order Management**: Issue, update, and close court orders
- **🏛️ Authorized Courts**: Multi-court support with authorization controls
- **📊 Compliance Tracking**: Monitor and flag compliance status
- **⏰ Deadline Management**: Set and extend deadlines for orders
- **🔍 Query System**: Search orders by subject, priority, or status
- **📈 Compliance History**: Track all status changes over time

## 🛠️ Installation

1. Install Clarinet:
```bash
npm install -g @hirosystems/clarinet-cli
```

2. Clone and navigate to the project:
```bash
git clone <repository-url>
cd Clarity-Powered-Court-Orders-Registry
```

3. Run tests:
```bash
clarinet test
```

## 📖 Usage

### 🏛️ Court Authorization

**Authorize a new court:**
```clarity
(contract-call? .clarity-powered-court-orders-registry authorize-court 'SP1234567890ABCDEF)
```

**Revoke court authorization:**
```clarity
(contract-call? .clarity-powered-court-orders-registry revoke-court 'SP1234567890ABCDEF)
```

### 📋 Court Order Management

**Issue a new court order:**
```clarity
(contract-call? .clarity-powered-court-orders-registry issue-court-order 
    "CASE-2024-001" 
    0x1234567890abcdef 
    "high" 
    u1000 
    'SP-SUBJECT-PRINCIPAL)
```

**Update compliance status:**
```clarity
(contract-call? .clarity-powered-court-orders-registry update-compliance-status u1 "compliant")
```

**Extend deadline:**
```clarity
(contract-call? .clarity-powered-court-orders-registry extend-deadline u1 u2000)
```

**Close an order:**
```clarity
(contract-call? .clarity-powered-court-orders-registry close-order u1)
```

### 🚩 Compliance Monitoring

**Flag pending obligations:**
```clarity
(contract-call? .clarity-powered-court-orders-registry flag-pending-obligation u1)
```

### 🔍 Query Functions

**Get court order details:**
```clarity
(contract-call? .clarity-powered-court-orders-registry get-court-order u1)
```

**Get orders by subject:**
```clarity
(contract-call? .clarity-powered-court-orders-registry get-orders-by-subject 'SP-SUBJECT-PRINCIPAL)
```

**Get compliance history:**
```clarity
(contract-call? .clarity-powered-court-orders-registry get-compliance-history u1)
```

**Get overdue orders:**
```clarity
(contract-call? .clarity-powered-court-orders-registry get-overdue-orders)
```

**Get orders by priority:**
```clarity
(contract-call? .clarity-powered-court-orders-registry get-orders-by-priority "high")
```

**Get orders by status:**
```clarity
(contract-call? .clarity-powered-court-orders-registry get-orders-by-status "active")
```

## 📊 Data Structures

### Court Order
- `court`: Principal of the issuing court
- `case-number`: Unique case identifier
- `ruling-hash`: Hash of the ruling document
- `status`: "active" or "closed"
- `priority`: "high", "medium", or "low"
- `issued-at`: Block height when issued
- `deadline`: Block height deadline
- `subject`: Principal subject to the order
- `compliance-status`: "pending", "compliant", "non-compliant", or "overdue"
- `last-updated`: Last modification block height

### Compliance History
- `timestamp`: Block height of status change
- `status`: Compliance status at that time
- `reporter`: Principal who reported the status

## 🔐 Security

- Only authorized courts can issue orders and update compliance
- Contract owner manages court authorizations
- All actions are logged with timestamps and reporter information
- Immutable on-chain record keeping

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For issues and questions, please open a GitHub issue or contact the development team.

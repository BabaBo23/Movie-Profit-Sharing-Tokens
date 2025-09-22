# 🎬 Movie Profit-Sharing Tokens

A decentralized platform for movie investment and profit sharing built on the Stacks blockchain. Investors can buy tokens representing shares in movie profits and automatically receive royalties based on box office performance reported by oracles.

## ✨ Features

### For Investors 💰
- **Movie Investment**: Purchase tokens representing shares in movie projects
- **Automatic Royalties**: Receive STX based on box office earnings
- **Portfolio Tracking**: Monitor your investments and returns
- **Transparent Claims**: Clear visibility into claimable royalties

### For Movie Creators 🎭
- **Crowdfunding**: Raise funds for movie projects through token sales
- **Flexible Funding**: Set target amounts and token supply
- **Fund Management**: Withdraw raised funds when targets are met
- **Project Control**: Manage movie project lifecycle

### For Oracles 🔮
- **Box Office Reporting**: Submit verified earnings data
- **Automated Distribution**: Trigger royalty calculations
- **Trusted Reports**: Authorized oracle system for data integrity

## 🚀 Getting Started

### Prerequisites
- Clarinet CLI installed
- Stacks wallet (Hiro Wallet recommended)
- Node.js for testing

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/movie-profit-sharing-tokens.git
cd movie-profit-sharing-tokens
```

2. Install dependencies:
```bash
npm install
```

3. Run tests:
```bash
npm test
```

4. Open the UI:
```bash
open index.html
```

## 📖 Usage Guide

### Creating a Movie Project

1. Navigate to the **Create Movie** tab
2. Fill in the movie details:
   - **Movie Title**: Name of your movie project
   - **Target Amount**: Funding goal in STX
   - **Token Supply**: Total number of tokens to issue
3. Click **Create Movie Project**

### Investing in Movies

1. Go to the **Invest** tab
2. Enter the **Movie ID** you want to invest in
3. Specify your **Investment Amount** in STX
4. View the expected tokens you'll receive
5. Click **Invest Now**

### Claiming Royalties

1. Visit the **Royalties** tab
2. Enter the **Movie ID** for which you want to claim royalties
3. Check your claimable amount
4. Click **Claim Royalties**

### Oracle Operations

1. Access the **Oracle** tab
2. Report box office earnings for movies
3. Set oracle addresses (contract owner only)

## 🏗️ Contract Architecture

### Core Functions

#### Public Functions
- `create-movie`: Create a new movie project
- `invest-in-movie`: Invest STX in a movie project
- `claim-royalties`: Claim earned royalties
- `report-box-office`: Report box office earnings (oracle only)
- `set-oracle`: Set authorized oracle address (owner only)

#### Read-Only Functions
- `get-movie-info`: Get movie project details
- `get-investor-balance`: Get investor's token balance
- `calculate-royalty-amount`: Calculate available royalties
- `get-claimable-royalties`: Get unclaimed royalty amount

### Data Structure

```clarity
{
  movie-id: uint,
  title: string,
  creator: principal,
  total-supply: uint,
  funds-raised: uint,
  target-amount: uint,
  box-office-earnings: uint,
  is-active: bool
}
```

## 💡 How It Works

1. **Movie Creation**: Creators launch movie projects with funding targets
2. **Investment Phase**: Investors purchase tokens proportional to their investment
3. **Production**: Movies are produced using raised funds
4. **Box Office Reporting**: Oracles report verified earnings data
5. **Royalty Distribution**: Investors claim their share of profits automatically

## 🔧 Development

### Running Tests
```bash
npm test
```

### Building the Contract
```bash
clarinet check
```

### Deployment
```bash
clarinet deploy
```

## 🛡️ Security Features

- **Oracle Authorization**: Only authorized oracles can report earnings
- **Owner Controls**: Contract owner manages critical functions
- **Input Validation**: Comprehensive parameter validation
- **Safe Math**: Prevents overflow and underflow issues
- **Access Control**: Role-based function access

## 📊 Economics

### Platform Fee
- Default: 2.5% of royalty claims
- Configurable by contract owner
- Supports platform maintenance and development

### Token Distribution
- Tokens issued proportionally to investment amount
- Total supply set by movie creator
- Immutable after creation

## 🌐 UI Features

### Responsive Design
- Mobile-friendly interface
- Accessible components
- Modern CSS animations
- Real-time updates

### Dashboard
- Investment portfolio overview
- Active movie projects
- Claimable royalties summary
- Platform statistics

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Stacks Foundation for the blockchain infrastructure
- Clarinet team for development tools
- Movie industry for inspiration

## 📞 Support

- GitHub Issues: Report bugs and request features
- Documentation: Comprehensive guides and API reference
- Community: Join our Discord for discussions

---

🎭 **Start your movie investment journey today!** 🚀

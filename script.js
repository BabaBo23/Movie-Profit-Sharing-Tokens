// class MovieProfitSharingApp {
//     constructor() {
//         this.contractAddress = 'SP1234567890ABCDEF.movie-profit-sharing';
//         this.currentMovieId = 1;
//         this.userAddress = 'SP1234567890ABCDEF';
//         this.isOracle = false;
//         this.init();
//     }

//     init() {
//         this.setupEventListeners();
//         this.loadDashboard();
//         this.setupTabSwitching();
//     }

//     setupEventListeners() {
//         document.getElementById('create-movie-form').addEventListener('submit', (e) => this.createMovie(e));
//         document.getElementById('invest-form').addEventListener('submit', (e) => this.investInMovie(e));
//         document.getElementById('royalties-form').addEventListener('submit', (e) => this.claimRoyalties(e));
//         document.getElementById('oracle-form').addEventListener('submit', (e) => this.reportBoxOffice(e));
//         document.getElementById('oracle-settings-form').addEventListener('submit', (e) => this.setOracle(e));
//         document.getElementById('close-status').addEventListener('click', () => this.hideStatus());
        
//         document.getElementById('invest-amount').addEventListener('input', (e) => this.calculateExpectedTokens(e));
//         document.getElementById('invest-movie-id').addEventListener('input', (e) => this.calculateExpectedTokens(e));
//         document.getElementById('royalty-movie-id').addEventListener('input', (e) => this.calculateClaimableAmount(e));
        
//         setInterval(() => this.updateDashboard(), 30000);
//     }

//     setupTabSwitching() {
//         const navButtons = document.querySelectorAll('.nav-btn');
//         const tabContents = document.querySelectorAll('.tab-content');

//         navButtons.forEach(button => {
//             button.addEventListener('click', () => {
//                 const targetTab = button.dataset.tab;
                
//                 navButtons.forEach(btn => btn.classList.remove('active'));
//                 tabContents.forEach(content => content.classList.remove('active'));
                
//                 button.classList.add('active');
//                 document.getElementById(targetTab).classList.add('active');
//             });
//         });
//     }

//     async createMovie(e) {
//         e.preventDefault();
        
//         const title = document.getElementById('movie-title').value;
//         const targetAmount = parseFloat(document.getElementById('target-amount').value);
//         const tokenSupply = parseInt(document.getElementById('token-supply').value);
        
//         if (!title || !targetAmount || !tokenSupply) {
//             this.showStatus('Please fill in all fields', 'error');
//             return;
//         }

//         try {
//             this.showStatus('Creating movie project...', 'info');
            
//             const movieId = await this.simulateTransaction('create-movie', {
//                 title,
//                 targetAmount: this.toMicroStx(targetAmount),
//                 tokenSupply
//             });
            
//             this.showStatus(`Movie project created successfully! Movie ID: ${movieId}`, 'success');
//             document.getElementById('create-movie-form').reset();
//             this.updateDashboard();
            
//         } catch (error) {
//             this.showStatus(`Error creating movie: ${error.message}`, 'error');
//         }
//     }

//     async investInMovie(e) {
//         e.preventDefault();
        
//         const movieId = parseInt(document.getElementById('invest-movie-id').value);
//         const amount = parseFloat(document.getElementById('invest-amount').value);
        
//         if (!movieId || !amount) {
//             this.showStatus('Please fill in all fields', 'error');
//             return;
//         }

//         try {
//             this.showStatus('Processing investment...', 'info');
            
//             const tokensReceived = await this.simulateTransaction('invest-in-movie', {
//                 movieId,
//                 amount: this.toMicroStx(amount)
//             });
            
//             this.showStatus(`Investment successful! Tokens received: ${tokensReceived}`, 'success');
//             document.getElementById('invest-form').reset();
//             this.updateDashboard();
            
//         } catch (error) {
//             this.showStatus(`Error investing: ${error.message}`, 'error');
//         }
//     }

//     async claimRoyalties(e) {
//         e.preventDefault();
        
//         const movieId = parseInt(document.getElementById('royalty-movie-id').value);
        
//         if (!movieId) {
//             this.showStatus('Please enter a movie ID', 'error');
//             return;
//         }

//         try {
//             this.showStatus('Claiming royalties...', 'info');
            
//             const claimedAmount = await this.simulateTransaction('claim-royalties', {
//                 movieId
//             });
            
//             this.showStatus(`Royalties claimed! Amount: ${this.fromMicroStx(claimedAmount)} STX`, 'success');
//             document.getElementById('royalties-form').reset();
//             this.updateDashboard();
            
//         } catch (error) {
//             this.showStatus(`Error claiming royalties: ${error.message}`, 'error');
//         }
//     }

//     async reportBoxOffice(e) {
//         e.preventDefault();
        
//         const movieId = parseInt(document.getElementById('oracle-movie-id').value);
//         const earnings = parseFloat(document.getElementById('box-office-earnings').value);
        
//         if (!movieId || !earnings) {
//             this.showStatus('Please fill in all fields', 'error');
//             return;
//         }

//         if (!this.isOracle) {
//             this.showStatus('Only authorized oracles can report box office earnings', 'error');
//             return;
//         }

//         try {
//             this.showStatus('Reporting box office earnings...', 'info');
            
//             const reportId = await this.simulateTransaction('report-box-office', {
//                 movieId,
//                 earnings: this.toMicroStx(earnings)
//             });
            
//             this.showStatus(`Box office reported successfully! Report ID: ${reportId}`, 'success');
//             document.getElementById('oracle-form').reset();
//             this.updateDashboard();
            
//         } catch (error) {
//             this.showStatus(`Error reporting box office: ${error.message}`, 'error');
//         }
//     }

//     async setOracle(e) {
//         e.preventDefault();
        
//         const oracleAddress = document.getElementById('oracle-address').value;
        
//         if (!oracleAddress) {
//             this.showStatus('Please enter an oracle address', 'error');
//             return;
//         }

//         try {
//             this.showStatus('Setting oracle address...', 'info');
            
//             await this.simulateTransaction('set-oracle', {
//                 oracleAddress
//             });
            
//             this.showStatus('Oracle address set successfully!', 'success');
//             document.getElementById('oracle-settings-form').reset();
            
//         } catch (error) {
//             this.showStatus(`Error setting oracle: ${error.message}`, 'error');
//         }
//     }

//     async calculateExpectedTokens(e) {
//         const movieId = parseInt(document.getElementById('invest-movie-id').value);
//         const amount = parseFloat(document.getElementById('invest-amount').value);
        
//         if (movieId && amount) {
//             try {
//                 const tokens = await this.simulateReadOnly('calculate-tokens-for-investment', {
//                     movieId,
//                     amount: this.toMicroStx(amount)
//                 });
                
//                 document.getElementById('expected-tokens').textContent = tokens || '0';
//             } catch (error) {
//                 document.getElementById('expected-tokens').textContent = '0';
//             }
//         } else {
//             document.getElementById('expected-tokens').textContent = '0';
//         }
//     }

//     async calculateClaimableAmount(e) {
//         const movieId = parseInt(document.getElementById('royalty-movie-id').value);
        
//         if (movieId) {
//             try {
//                 const amount = await this.simulateReadOnly('get-claimable-royalties', {
//                     movieId,
//                     investor: this.userAddress
//                 });
                
//                 document.getElementById('claimable-amount').textContent = `${this.fromMicroStx(amount)} STX`;
//             } catch (error) {
//                 document.getElementById('claimable-amount').textContent = '0 STX';
//             }
//         } else {
//             document.getElementById('claimable-amount').textContent = '0 STX';
//         }
//     }

//     async loadDashboard() {
//         this.updateDashboard();
//     }

//     async updateDashboard() {
//         try {
//             const nextMovieId = await this.simulateReadOnly('get-next-movie-id', {});
//             const totalMovies = nextMovieId - 1;
            
//             document.getElementById('total-movies').textContent = totalMovies;
            
//             const platformFee = await this.simulateReadOnly('get-platform-fee', {});
//             document.getElementById('platform-fee').textContent = `${platformFee / 100}%`;
            
//             let totalClaimable = 0;
//             let userInvestments = 0;
            
//             for (let i = 1; i <= totalMovies; i++) {
//                 const balance = await this.simulateReadOnly('get-investor-balance', {
//                     movieId: i,
//                     investor: this.userAddress
//                 });
                
//                 if (balance && balance > 0) {
//                     userInvestments++;
//                     const claimable = await this.simulateReadOnly('get-claimable-royalties', {
//                         movieId: i,
//                         investor: this.userAddress
//                     });
//                     totalClaimable += claimable || 0;
//                 }
//             }
            
//             document.getElementById('your-investments').textContent = userInvestments;
//             document.getElementById('claimable-royalties').textContent = `${this.fromMicroStx(totalClaimable)} STX`;
            
//             await this.loadMoviesList(totalMovies);
            
//         } catch (error) {
//             console.error('Error updating dashboard:', error);
//         }
//     }

//     async loadMoviesList(totalMovies) {
//         const container = document.getElementById('movies-container');
//         container.innerHTML = '<div class="loading">Loading movies...</div>';
        
//         if (totalMovies === 0) {
//             container.innerHTML = '<div class="loading">No movies created yet</div>';
//             return;
//         }
        
//         let moviesHtml = '';
        
//         for (let i = 1; i <= totalMovies; i++) {
//             try {
//                 const movie = await this.simulateReadOnly('get-movie-info', { movieId: i });
                
//                 if (movie && movie.isActive) {
//                     const progress = await this.simulateReadOnly('get-movie-funding-progress', { movieId: i });
//                     const progressPercent = progress / 100;
                    
//                     moviesHtml += this.generateMovieCard(i, movie, progressPercent);
//                 }
//             } catch (error) {
//                 console.error(`Error loading movie ${i}:`, error);
//             }
//         }
        
//         container.innerHTML = moviesHtml || '<div class="loading">No active movies found</div>';
//     }

//     generateMovieCard(movieId, movie, progressPercent) {
//         return `
//             <div class="movie-card">
//                 <h4>${movie.title}</h4>
//                 <div class="movie-details">
//                     <div class="movie-detail">
//                         <strong>Movie ID:</strong> ${movieId}
//                     </div>
//                     <div class="movie-detail">
//                         <strong>Target:</strong> ${this.fromMicroStx(movie.targetAmount)} STX
//                     </div>
//                     <div class="movie-detail">
//                         <strong>Raised:</strong> ${this.fromMicroStx(movie.fundsRaised)} STX
//                     </div>
//                     <div class="movie-detail">
//                         <strong>Tokens:</strong> ${movie.totalSupply}
//                     </div>
//                     <div class="movie-detail">
//                         <strong>Box Office:</strong> ${this.fromMicroStx(movie.boxOfficeEarnings)} STX
//                     </div>
//                     <div class="movie-detail">
//                         <strong>Creator:</strong> ${movie.creator.substring(0, 10)}...
//                     </div>
//                 </div>
//                 <div class="progress-bar">
//                     <div class="progress-fill" style="width: ${Math.min(progressPercent, 100)}%"></div>
//                 </div>
//             </div>
//         `;
//     }

//     async simulateTransaction(functionName, args) {
//         await this.delay(1000);
        
//         switch (functionName) {
//             case 'create-movie':
//                 return this.currentMovieId++;
//             case 'invest-in-movie':
//                 return Math.floor(args.amount * 0.1);
//             case 'claim-royalties':
//                 return Math.floor(Math.random() * 10000000);
//             case 'report-box-office':
//                 return 1;
//             case 'set-oracle':
//                 this.isOracle = true;
//                 return true;
//             default:
//                 throw new Error('Unknown function');
//         }
//     }

//     async simulateReadOnly(functionName, args) {
//         await this.delay(100);
        
//         switch (functionName) {
//             case 'get-next-movie-id':
//                 return this.currentMovieId;
//             case 'get-platform-fee':
//                 return 250;
//             case 'get-investor-balance':
//                 return Math.random() > 0.7 ? Math.floor(Math.random() * 1000) : 0;
//             case 'get-claimable-royalties':
//                 return Math.floor(Math.random() * 5000000);
//             case 'calculate-tokens-for-investment':
//                 return Math.floor(args.amount * 0.1);
//             case 'get-movie-info':
//                 if (args.movieId < this.currentMovieId) {
//                     return {
//                         title: `Movie ${args.movieId}`,
//                         creator: 'SP1234567890ABCDEF',
//                         totalSupply: 1000,
//                         fundsRaised: Math.floor(Math.random() * 50000000),
//                         targetAmount: 100000000,
//                         boxOfficeEarnings: Math.floor(Math.random() * 200000000),
//                         isActive: true,
//                         creationBlock: 1000,
//                         distributionCount: 0
//                     };
//                 }
//                 return null;
//             case 'get-movie-funding-progress':
//                 return Math.floor(Math.random() * 8500);
//             default:
//                 return 0;
//         }
//     }

//     toMicroStx(amount) {
//         return Math.floor(amount * 1000000);
//     }

//     fromMicroStx(microStx) {
//         return (microStx / 1000000).toFixed(6);
//     }

//     delay(ms) {
//         return new Promise(resolve => setTimeout(resolve, ms));
//     }

//     showStatus(message, type = 'info') {
//         const statusEl = document.getElementById('status');
//         const messageEl = document.getElementById('status-message');
        
//         statusEl.className = `status ${type}`;
//         messageEl.textContent = message;
//         statusEl.classList.remove('hidden');
//         statusEl.classList.add('show');
        
//         setTimeout(() => {
//             this.hideStatus();
//         }, 5000);
//     }

//     hideStatus() {
//         const statusEl = document.getElementById('status');
//         statusEl.classList.remove('show');
//         setTimeout(() => {
//             statusEl.classList.add('hidden');
//         }, 300);
//     }
// }

// document.addEventListener('DOMContentLoaded', () => {
//     new MovieProfitSharingApp();
// });

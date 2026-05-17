# HCPilot Web Dashboard Setup

## Prerequisites

- Node.js 18+
- npm or yarn

## Installation

1. Install dependencies:
```bash
npm install
# or
yarn install
```

2. Run development server:
```bash
npm run dev
# or
yarn dev
```

The application will be available at `http://localhost:5173`

## Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run lint` - Run ESLint

## Project Structure

```
web/
├── src/
│   ├── components/     # React components
│   ├── layouts/        # Layout components
│   ├── pages/          # Page components
│   ├── stores/         # Zustand state management
│   ├── lib/            # Utility functions
│   └── App.tsx         # Main app component
├── tailwind.config.js  # Tailwind CSS configuration
└── vite.config.ts      # Vite configuration
```

## State Management

The app uses Zustand for state management:

- `auth` - Authentication state
- `patient` - Patient data
- `visit` - Visit data
- `invoice` - Invoice data
- `stock` - Stock data
- `dashboard` - Dashboard statistics

## API Integration

The app connects to the FastAPI backend at `http://localhost:8000`. Configure the backend URL in `src/lib/api.ts`.

## Deployment

The app can be deployed to:
- Vercel
- Netlify
- GitHub Pages
- Any static hosting service

```bash
npm run build
# Deploy the dist/ directory
```

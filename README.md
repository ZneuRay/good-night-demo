# Good Night API - Sleep Tracking Application

A Ruby on Rails API application for tracking sleep patterns with social features. Users can record their sleep sessions and follow friends to view their sleep data.

## Features

- 🛌 **Sleep Tracking**: Clock in/out functionality for tracking sleep sessions
- 👥 **Social Features**: Follow/unfollow users and view friends' sleep records
- 📊 **Analytics**: View sleep records sorted by duration
- ⚡ **High Performance**: Optimized with strategic caching and background processing

## Quick Start

### Prerequisites

- Ruby 3.2+
- Rails 8.0
- PostgreSQL 14+

### Installation

```bash
# Clone the repository
git clone https://github.com/zneuray/good-night-demo.git
cd good-night-demo

# Install dependencies
bundle install

# Setup database
rails db:create db:migrate db:seed

# Start SolidQueue (for background job)
rails solid_queue:start

# Start the application
rails server
```

The API will be available at `http://localhost:3000`

## API Documentation

### Sleep Records

#### Clock In
Start a new sleep session.

#### Clock Out
End the most recent sleep session.

#### Get Sleep Records
Retrieve all completed sleep records for the authenticated user.

#### Get Following Sleep Records
Retrieve friends' sleep records from the previous week, sorted by duration.

### User Following

#### Follow User
Follow another user to see their sleep records.

#### Unfollow User
Stop following a user.

## Architecture

### Performance Optimizations

The application implements several performance strategies optimized for large datasets:

#### Solid Cache for Large Data Caching
The application uses **Solid Cache** - a database-backed cache store perfect for handling large datasets and high-traffic applications:

- **High Performance**: SQLite-based caching with excellent read/write performance
- **Large Data Support**: Handles multi-gigabyte cache datasets efficiently
- **Persistence**: Cache survives application restarts unlike memory-based stores
- **Scalability**: Designed for production applications with high cache volumes

#### Strategic Caching with Optimized TTLs
- **Last Incomplete Sleep Record**: 24 hours TTL
- **Following Sleep Records**: 1 hour TTL
- **Weekly Sleep Data**: 1 month TTL
- **User Following Lists**: 6 hours TTL

#### Database Optimization for Large Datasets
- **Composite Indexes**: Optimized for frequently queried columns
- **Partial Indexes**: For incomplete sleep records
- **Database-Level Sorting**: Using stored duration column for performance
- **Optimized queries**: Use includes to avoid N+1 problems

#### Background Processing with Solid Queue
- **Asynchronous Cache Warming**: Pre-compute expensive queries
- **Weekly Analytics Processing**: Background computation of sleep statistics
- **Batch Cache Updates**: Efficient handling of large follower lists

### Service Architecture

The application follows Rails best practices with service objects for complex business logic:

```
app/
├── controllers/api/users/
│   └── sleep_records_controller.rb    # Thin controllers
├── models/
│   ├── user.rb                        # User relationships and social features
│   ├── sleep_record.rb                # Sleep data with duration tracking
│   └── follow.rb                      # Following relationships
├── services/sleep/
│   ├── clock_in_service.rb            # Sleep session creation
│   ├── clock_out_service.rb           # Sleep session completion
│   ├── following_service.rb           # Social sleep data retrieval
│   └── cache_handle_service.rb        # Centralized caching logic
└── serializers/
    └── sleep_records_serializer.rb    # Consistent API responses
```

## Business Logic

### Sleep Tracking Rules

1. **Clock In**: Always creates a new sleep record with `duration: 0`
2. **Clock Out**: Updates the most recent incomplete sleep record
3. **Multiple Clock-ins**: Allowed - creates multiple incomplete records
4. **Clock Out Logic**: Only completes the latest incomplete record
5. **Duration Calculation**: Automatically calculated on clock out

### Social Features

1. **Following**: Users can follow/unfollow each other
2. **Sleep Visibility**: Only completed sleep records are visible to followers
3. **Time Period**: Following endpoint shows previous week's data only
4. **Sorting**: Results sorted by sleep duration (descending)

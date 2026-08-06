# Requirements

## What we know about the data

- Patient data is already collected (pregnancies, age, BMI, ...)
- Patient data is in a patient database


## Team Profile

- Python developers
- Likes plain csv files
- Likes jupyter notebooks

## Scalability and Security

- we need a scalable solution
- privacy-sensitive data must be extracted into Azure storage we can govern


## How the app will use the model

1. Doctors enter patient info
2. Doctors tap Analyze
3. Doctors expects a prediction immediately


## Latency Requirements

- Consultations are under 10 minutes
- Model must be always-on and respond fast


## Batch vs Single

- Doctors will request one patient at a time
- Predictions are individual and on-demand

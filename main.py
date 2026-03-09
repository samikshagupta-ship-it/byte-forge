"""
SafeReport Backend - No API Key Required
Uses rule-based credibility scoring
Run: pip install fastapi uvicorn sqlalchemy python-multipart
     uvicorn main:app --host 0.0.0.0 --port 8000
"""

from fastapi import FastAPI, File, UploadFile, Form, HTTPException, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from datetime import datetime
from pathlib import Path
from typing import Optional
import os
import uuid
import shutil
import re
from dotenv import load_dotenv
import requests
import json

load_dotenv()

app = FastAPI(title="Sentinel AI - Ethical Predictive Safety System", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

templates = Jinja2Templates(directory="templates")
app.mount("/static", StaticFiles(directory="static"), name="static")
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./reports.db")
engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False} if "sqlite" in DATABASE_URL else {}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

UPLOAD_DIR = Path("uploads")
UPLOAD_DIR.mkdir(exist_ok=True)


# ==================== DATABASE MODEL ====================

class Report(Base):
    __tablename__ = "reports"
    
    id = Column(Integer, primary_key=True, index=True)
    token = Column(String, unique=True, index=True)
    category = Column(String, nullable=False)
    description = Column(Text, nullable=False)
    credibility_score = Column(Integer, default=0)
    summary = Column(Text, default="")
    file_path = Column(String, nullable=True)
    location = Column(String, nullable=True)
    lat = Column(String, nullable=True)
    lng = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    status = Column(String, default="under_review")


Base.metadata.create_all(bind=engine)


# ==================== FREE AI ANALYSIS (Rule-Based) ====================

def analyze_report_free(category: str, description: str) -> dict:
    """
    FREE rule-based analysis - no API key needed
    Scores based on content quality indicators
    """
    score = 50  # Base score
    indicators = []
    
    # Length check (more detail = higher score)
    word_count = len(description.split())
    if word_count > 100:
        score += 15
        indicators.append("Detailed description")
    elif word_count > 50:
        score += 10
        indicators.append("Moderate detail")
    elif word_count < 20:
        score -= 10
        indicators.append("Lacks detail")
    
    # Specific indicators of credible reports
    credibility_markers = [
        r'\$\d+',  # Dollar amounts
        r'\d{1,2}/\d{1,2}/\d{2,4}',  # Dates
        r'\d{1,2}:\d{2}',  # Times
        r'(January|February|March|April|May|June|July|August|September|October|November|December)',  # Month names
        r'(Mr\.|Mrs\.|Ms\.|Dr\.|Officer|Manager|Director)',  # Titles
        r'(building|office|room|floor|street|avenue|road)',  # Locations
    ]
    
    marker_count = 0
    for pattern in credibility_markers:
        if re.search(pattern, description, re.IGNORECASE):
            marker_count += 1
    
    if marker_count >= 4:
        score += 20
        indicators.append("Highly specific details")
    elif marker_count >= 2:
        score += 10
        indicators.append("Some specific details")
    
    # Evidence keywords
    evidence_words = ['photo', 'video', 'recording', 'document', 'email', 'receipt', 'witness', 'proof']
    evidence_found = [w for w in evidence_words if w in description.lower()]
    if evidence_found:
        score += 10
        indicators.append(f"Mentions evidence: {', '.join(evidence_found[:2])}")
    
    # Urgency/impact indicators
    urgency_words = ['multiple', 'everyone', 'systematic', 'ongoing', 'repeated', 'many people']
    if any(w in description.lower() for w in urgency_words):
        score += 5
        indicators.append("Indicates systemic issue")
    
    # Red flags (reduce score)
    red_flags = ['i think', 'maybe', 'probably', 'not sure', 'rumor', 'hearsay']
    flag_count = sum(1 for flag in red_flags if flag in description.lower())
    if flag_count > 0:
        score -= 10 * flag_count
        indicators.append("Contains uncertainty")
    
    # Clamp score
    score = max(0, min(100, score))
    
    # Generate summary
    if score >= 70:
        level = "High"
        action = "Priority review recommended"
    elif score >= 40:
        level = "Medium"
        action = "Standard review process"
    else:
        level = "Low"
        action = "Additional verification needed"
    
    summary = f"{level} credibility ({score}/100). "
    if indicators:
        summary += f"Indicators: {'; '.join(indicators[:3])}. "
    summary += action
    
    return {
        "credibility_score": score,
        "summary": summary
    }


# ==================== HELPER FUNCTIONS ====================

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def generate_token() -> str:
    return uuid.uuid4().hex[:8].upper()

def geocode_location(location: str):
    """Geocode location to lat/lng using Nominatim"""
    if not location:
        return None, None
    try:
        url = f"https://nominatim.openstreetmap.org/search?q={location}&format=json&limit=1"
        response = requests.get(url, headers={'User-Agent': 'SafeReport/1.0'})
        data = response.json()
        if data:
            return data[0]['lat'], data[0]['lon']
    except:
        pass
    return None, None


# ==================== API ENDPOINTS ====================

@app.get("/")
def root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})


@app.get("/submit")
def submit_form(request: Request):
    return templates.TemplateResponse("submit.html", {"request": request})


@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "ai_engine": "Rule-based analysis (Free)",
        "database": "connected",
        "cost": "$0 - No external APIs"
    }


@app.post("/submit-report")
async def submit_report(
    category: str = Form(...),
    description: str = Form(...),
    location: str = Form(""),
    file: UploadFile = File(None),
    db: Session = Depends(get_db)
):
    """Submit report with FREE AI analysis"""
    token = generate_token()
    
    # Geocode location
    lat, lng = geocode_location(location)
    
    # Handle file
    file_path = None
    if file and file.filename:
        safe_name = f"{token}_{file.filename.replace(' ', '_')}"
        file_location = UPLOAD_DIR / safe_name
        try:
            with open(file_location, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            file_path = str(file_location)
        except Exception as e:
            print(f"File error: {e}")
    
    # FREE AI Analysis (no API key)
    analysis = analyze_report_free(category, description)
    
    # Save to DB
    db_report = Report(
        token=token,
        category=category,
        description=description,
        credibility_score=analysis["credibility_score"],
        summary=analysis["summary"],
        file_path=file_path,
        location=location,
        lat=lat,
        lng=lng
    )
    
    db.add(db_report)
    db.commit()
    
    return RedirectResponse(url=f"/report/{token}", status_code=303)


@app.get("/report/{token}")
def get_report(token: str, request: Request, db: Session = Depends(get_db)):
    """Get report by token"""
    report = db.query(Report).filter(Report.token == token).first()
    
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    
    return templates.TemplateResponse("report.html", {"request": request, "report": report})


@app.get("/reports")
def list_reports(request: Request, skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """List all reports"""
    reports = db.query(Report).order_by(Report.created_at.desc()).offset(skip).limit(limit).all()
    
    return templates.TemplateResponse("reports.html", {"request": request, "reports": reports})


@app.get("/map")
def crime_map(request: Request, db: Session = Depends(get_db)):
    """Show crime map"""
    reports = db.query(Report).filter(Report.lat.isnot(None), Report.lng.isnot(None)).all()
    reports_data = []
    for r in reports:
        reports_data.append({
            'id': r.id,
            'category': r.category,
            'description': r.description[:100] + '...' if len(r.description) > 100 else r.description,
            'lat': r.lat,
            'lng': r.lng,
            'token': r.token
        })
    return templates.TemplateResponse("map.html", {"request": request, "reports_json": json.dumps(reports_data)})


@app.get("/trends")
def trends(request: Request):
    """Show trends and statistics"""
    return templates.TemplateResponse("trends.html", {"request": request})
def get_statistics(db: Session = Depends(get_db)):
    """Get statistics"""
    total = db.query(Report).count()
    high = db.query(Report).filter(Report.credibility_score >= 70).count()
    medium = db.query(Report).filter(Report.credibility_score >= 40, Report.credibility_score < 70).count()
    low = db.query(Report).filter(Report.credibility_score < 40).count()
    
    return {
        "total_reports": total,
        "high_credibility": high,
        "medium_credibility": medium,
        "low_credibility": low,
        "free_ai_enabled": True
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
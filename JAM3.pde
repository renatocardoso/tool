import processing.sound.*;
import controlP5.*;
import processing.svg.*;
import gifAnimation.*; // 1. Biblioteca importada
import java.util.ArrayList;

import java.awt.Font;
import java.awt.font.FontRenderContext;
import java.awt.font.GlyphVector;
import java.awt.Shape;
import java.awt.geom.PathIterator;
import java.awt.geom.FlatteningPathIterator;

SoundFile track;
FFT fft;
int bands = 512;
float[] spectrum = new float[bands];

ControlP5 cp5;
public float intensity = 72; 
public float strokeThickness = 4.0; 
public float micGain = 1.0; 
public float dirBias = 0.5;      // 0.0 (Horizontal) a 1.0 (Vertical)
public float shapeStyle = 1.0;   // 0.0 (Angular) a 1.0 (Arredondado)
public float pointSpacing = 4.0; // Distância entre pontos (Densidade)
float lastPointSpacing = -1;

boolean recordSVG = false; 

// Variáveis para gravação do GIF
GifMaker gifExport;
boolean isRecordingGif = false;

ArrayList<ArrayList<PVector>> rawContours; 
ArrayList<ArrayList<PVector>> typographyContours; 
String textString = "JAM";
int fontSize = 350;

void setup() {
  size(1600, 1200); 

  track = new SoundFile(this, "Track2.mp3");
  track.loop(); 

  fft = new FFT(this, bands);
  fft.input(track);

  cp5 = new ControlP5(this);
  
  cp5.addSlider("intensity") 
     .setPosition(26, 26).setRange(0, 100).setValue(72).setSize(260, 26)
     .setCaptionLabel("Intensidade").setColorCaptionLabel(0)
     .getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10);

  cp5.addSlider("strokeThickness") 
     .setPosition(26, 60).setRange(1, 40).setValue(4).setSize(260, 26)
     .setCaptionLabel("Espessura").setColorCaptionLabel(0)
     .getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10);

  cp5.addSlider("micGain") 
     .setPosition(26, 94).setRange(0, 5).setValue(1.5).setSize(260, 26)
     .setCaptionLabel("Ganho de Audio").setColorCaptionLabel(0)
     .getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10);

  cp5.addSlider("dirBias") 
     .setPosition(26, 128).setRange(0.0, 1.0).setValue(0.5).setSize(260, 26)
     .setCaptionLabel("Direcao (0=Horiz, 1=Vert)").setColorCaptionLabel(0)
     .getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10);

  cp5.addSlider("shapeStyle") 
     .setPosition(26, 162).setRange(0.0, 1.0).setValue(1.0).setSize(260, 26)
     .setCaptionLabel("Forma (0=Angular, 1=Redonda)").setColorCaptionLabel(0)
     .getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10);

  cp5.addSlider("pointSpacing") 
     .setPosition(26, 196).setRange(1.0, 30.0).setValue(4.0).setSize(260, 26)
     .setCaptionLabel("Espacamento dos Pontos").setColorCaptionLabel(0)
     .getCaptionLabel().align(ControlP5.RIGHT_OUTSIDE, ControlP5.CENTER).setPaddingX(10);

  cp5.addButton("triggerSVGExport")
     .setPosition(26, 230).setSize(260, 39)
     .setCaptionLabel("EXPORTAR VETOR ATUAL (SVG)");

  // 2. Botão para reiniciar a música
  cp5.addButton("resetMusic")
     .setPosition(26, 280).setSize(260, 39)
     .setCaptionLabel("REINICIAR MUSICA");

  // 3. Botão para gravar GIF
  cp5.addButton("btnToggleGif")
     .setPosition(26, 330).setSize(260, 39)
     .setCaptionLabel("INICIAR / PARAR GRAVACAO DE GIF");

  float baselineX = width / 2 - 400;
  float baselineY = height / 2 + 120;

  java.awt.Font awtFont = null;
  
  try {
    java.io.File fontFile = new java.io.File(dataPath("VAG.otf"));
    java.awt.Font baseFont = java.awt.Font.createFont(java.awt.Font.TRUETYPE_FONT, fontFile);
    awtFont = baseFont.deriveFont(java.awt.Font.BOLD, (float)fontSize);
    
    java.awt.GraphicsEnvironment ge = java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment();
    ge.registerFont(awtFont);
  } catch (Exception e) {
    println("Erro ao carregar a fonte VAG.otf da pasta data:");
    e.printStackTrace();
    awtFont = new java.awt.Font("VAG.otf", java.awt.Font.BOLD, fontSize); 
  }

  FontRenderContext frc = new FontRenderContext(null, true, true);
  GlyphVector gv = awtFont.createGlyphVector(frc, textString);
  Shape textOutlineShape = gv.getOutline(baselineX, baselineY);

  FlatteningPathIterator fpi = new FlatteningPathIterator(textOutlineShape.getPathIterator(null), 0.05);
  float[] pointsCoords = new float[6];
  rawContours = new ArrayList<ArrayList<PVector>>();
  ArrayList<PVector> currentContour = null;

  while (!fpi.isDone()) {
    int segmentType = fpi.currentSegment(pointsCoords);
    switch(segmentType) {
      case PathIterator.SEG_MOVETO: 
        if (currentContour != null) rawContours.add(currentContour); 
        currentContour = new ArrayList<PVector>(); 
        currentContour.add(new PVector(pointsCoords[0], pointsCoords[1]));
        break;
      case PathIterator.SEG_LINETO: 
        if (currentContour != null) currentContour.add(new PVector(pointsCoords[0], pointsCoords[1]));
        break;
      case PathIterator.SEG_CLOSE: 
        if (currentContour != null) {
          rawContours.add(currentContour); 
          currentContour = null; 
        }
        break;
    }
    fpi.next();
  }
}

void draw() {
  background(255); 

  if (pointSpacing != lastPointSpacing) {
    typographyContours = resampleContours(rawContours, pointSpacing);
    lastPointSpacing = pointSpacing;
  }

  if (recordSVG) beginRecord(SVG, "exportacao-jam-####.svg");

  noFill(); 
  stroke(0); 
  strokeWeight(strokeThickness);
  strokeJoin(ROUND); 
  strokeCap(ROUND);

  float tightness = map(shapeStyle, 0.0, 1.0, 1.0, 0.0);
  curveTightness(tightness);

  fft.analyze(spectrum);
  
  float sumBass = 0;
  int bandsDetected = 0;
  for(int i = 0; i < 10; i++) {
    sumBass += spectrum[i];
    bandsDetected++;
  }
  
  float currentBassEnergy = (bandsDetected > 0) ? sumBass / bandsDetected : 0;
  currentBassEnergy *= micGain;

  float maxOffset = map(intensity, 0, 100, 0, 25);
  float audioScaleFactor = map(currentBassEnergy, 0, 0.05, 0, 15.0); 

  float hWeight = cos(dirBias * HALF_PI);
  float vWeight = sin(dirBias * HALF_PI);

  for (ArrayList<PVector> contour : typographyContours) {
    if (contour.size() < 3) continue;
    
    beginShape(); 
    int limit = contour.size() + 3; 
    
    for (int i = 0; i < limit; i++) {
      PVector pOrig = contour.get(i % contour.size());
      
      float noiseValueX = noise(pOrig.x * 0.015, pOrig.y * 0.015, frameCount * 0.02) - 0.5;
      float noiseValueY = noise(pOrig.y * 0.015, pOrig.x * 0.015, frameCount * 0.02 + 100) - 0.5;

      float shiftX = noiseValueX * maxOffset * audioScaleFactor * hWeight;
      float shiftY = noiseValueY * maxOffset * audioScaleFactor * vWeight;

      curveVertex(pOrig.x + shiftX, pOrig.y + shiftY); 
    }
    endShape(); 
  }

  if (recordSVG) {
    endRecord();
    recordSVG = false;
    println("Arquivo SVG gerado na pasta do sketch.");
  }

  drawAudioSpectrum();

  // 4. Lógica de captura de quadros para o GIF (Antes do indicador UI para não gravá-lo)
  if (isRecordingGif) {
    // Para manter o GIF menor que 5MB em uma tela de 1600x1200, gravamos 1 a cada 3 frames (aprox 20fps)
    if (frameCount % 3 == 0) {
      gifExport.setDelay(1000 / 20);
      gifExport.addFrame();
    }
    
    // Indicador visual de gravação (Bolinha vermelha no topo direito)
    pushStyle();
    fill(255, 0, 0);
    noStroke();
    ellipse(width - 40, 40, 20, 20);
    popStyle();
  }
}

// --- NOVAS FUNÇÕES DOS BOTÕES ---

public void resetMusic() {
  if (track != null) {
    track.stop();
    track.loop(); // Reinicia a faixa do começo
  }
}

public void btnToggleGif() {
  isRecordingGif = !isRecordingGif;
  
  if (isRecordingGif) {
    // Inicia a gravação
    gifExport = new GifMaker(this, "animacao-jam.gif");
    gifExport.setRepeat(0); // Faz o GIF rodar em loop infinito
    println("Gravando GIF... Pressione o botão novamente para parar.");
  } else {
    // Para e salva a gravação
    gifExport.finish();
    println("GIF salvo com sucesso na pasta do sketch!");
  }
}

// --------------------------------

public void triggerSVGExport() {
  recordSVG = true;
}

ArrayList<ArrayList<PVector>> resampleContours(ArrayList<ArrayList<PVector>> original, float spacing) {
  ArrayList<ArrayList<PVector>> resampled = new ArrayList<ArrayList<PVector>>();
  for (ArrayList<PVector> contour : original) {
    ArrayList<PVector> newContour = new ArrayList<PVector>();
    for (int i = 0; i < contour.size(); i++) {
      PVector p1 = contour.get(i);
      PVector p2 = contour.get((i + 1) % contour.size()); 
      newContour.add(p1);
      
      float dist = PVector.dist(p1, p2);
      if (dist > spacing) {
        int steps = floor(dist / spacing);
        for (int j = 1; j < steps; j++) {
          float t = (float) j / steps;
          newContour.add(new PVector(lerp(p1.x, p2.x, t), lerp(p1.y, p2.y, t)));
        }
      }
    }
    resampled.add(newContour);
  }
  return resampled;
}

void drawAudioSpectrum() {
  pushStyle();
  strokeWeight(2);
  strokeJoin(MITER);
  float visWidth = width - 40;
  int visibleBands = 120; 
  float bandWidth = visWidth / visibleBands;
  
  for (int i = 0; i < visibleBands; i++) {
    float x = 20 + (i * bandWidth);
    float h = spectrum[i] * 400 * micGain; 
    stroke(i < 10 ? color(255, 0, 0) : color(200)); 
    line(x, height - 20, x, height - 20 - h);
  }
  popStyle();
}

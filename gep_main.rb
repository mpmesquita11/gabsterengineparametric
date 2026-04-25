require 'sketchup.rb'
require 'json'

module Gabster
  module EngineParametric
    
    # ==============================
    # ABRIR INTERFACE
    # ==============================
    def self.abrir_gep
      @dialog = UI::HtmlDialog.new({
        :dialog_title => "GEP - Gabster Engine Parametric",
        :width => 900,
        :height => 700,
        :style => UI::HtmlDialog::STYLE_DIALOG
      })

      html_path = UI.openpanel("Selecione o arquivo gep_core.html", "", "HTML Files|*.html;||")
      return unless html_path
      
      @dialog.set_file(html_path)

      # RECEBE JSON DO JS
      @dialog.add_action_callback("enviarParaRuby") do |action_context, json_string|
        dados_json = JSON.parse(json_string)
        
        if dados_json.key?("erro")
          UI.messagebox("Erro no GEP: #{dados_json['erro']}")
        else
          self.gerar_geometria(dados_json)
        end
      end

      # CARREGAR DADOS DO COMPONENTE SELECIONADO
      sel = Sketchup.active_model.selection
      if sel.length == 1 && sel[0].is_a?(Sketchup::ComponentInstance)

        inst = sel[0]
        json = inst.definition.get_attribute("gabster_gep","dados_originais")

        if json
          @dialog.add_action_callback("pedirDados") do |_|
            @dialog.execute_script("carregarDadosExistentes(#{json})")
          end
        end

      end

      @dialog.show
    end


    # ==============================
    # GERAR GEOMETRIA
    # ==============================
    def self.gerar_geometria(dados)
      modelo = Sketchup.active_model
      modelo.start_operation('Gerar Componente GEP', true)

      x_mm = dados.dig("X", "value") || 800.0
      y_mm = dados.dig("Y", "value") || 500.0
      z_mm = dados.dig("Z", "value") || 500.0 

      x = x_mm.to_f.mm
      y = y_mm.to_f.mm
      z = z_mm.to_f.mm

      defn = modelo.definitions.add("GEP_Componente_#{Time.now.to_i}")

      pts = [ [0,0,0], [x,0,0], [x,y,0], [0,y,0] ]
      face = defn.entities.add_face(pts)
      face.reverse! if face.normal.z < 0
      face.pushpull(z)

      # POSIÇÃO
      posx = dados.dig("PosX","value") || 0
      posy = dados.dig("PosY","value") || 0
      posz = dados.dig("PosZ","value") || 0

      trans = Geom::Transformation.new([
        posx.to_f.mm,
        posy.to_f.mm,
        posz.to_f.mm
      ])

      instancia = modelo.active_entities.add_instance(defn, trans)
      instancia.name = "Peça Paramétrica GEP"

      # MATERIAL
      nome_material = dados.dig("Material","value")

      if nome_material && nome_material != ""
        mats = modelo.materials
        material = mats[nome_material] || mats.add(nome_material)
        instancia.material = material
      end

      # SALVAR JSON NO COMPONENTE
      defn.set_attribute(
        "gabster_gep",
        "dados_originais",
        dados.to_json
      )

      modelo.commit_operation
      puts "✅ GEP: Componente gerado com sucesso!"
    end

  end
end


unless file_loaded?(__FILE__)
  menu = UI.menu('Plugins')
  menu.add_item('🌟 Abrir Gabster GEP') {
    Gabster::EngineParametric.abrir_gep
  }
  file_loaded(__FILE__)
end
/**
 * SISREG - VISUALIZADOR DE OFERTAS [VERSÃO COM CONTROLE DE ACESSO]
 * Arquivo: Code.gs
 * Descrição: Backend do Google Apps Script com:
 * - CONTROLE DE ACESSO POR EMAIL
 * - Separação de agenda local/não local
 * - Filtros cascata (prestador → categorias)
 * - Filtro de grupo (procedimento_nome)
 * - Número da escala
 * - Detecção de escalas compartilhadas
 */

// ============================================
// CONFIGURAÇÕES GLOBAIS
// ============================================

const CONFIG = {
  SHEET_NAME: 'Dados Brutos HISTOCON',
  PERMISSOES_SHEET: 'Permissoes',  // NOVA ABA DE PERMISSÕES
  APP_NAME: 'SISREG - Visualizador de Ofertas',
  CACHE_DURATION: 300
};

const DIAS_SEMANA = {
  'SEG': 'Segunda-feira',
  'TER': 'Terça-feira',
  'QUA': 'Quarta-feira',
  'QUI': 'Quinta-feira',
  'SEX': 'Sexta-feira',
  'SAB': 'Sábado',
  'DOM': 'Domingo'
};

// ============================================
// SISTEMA DE CACHE
// ============================================

/**
 * Gera uma chave de cache única por usuário
 */
function getCacheKey(tipo) {
  var email = getUsuarioAtual() || 'anonimo';
  return tipo + '_' + email.replace(/[^a-zA-Z0-9]/g, '_');
}

/**
 * Obtém dados do cache
 */
function getFromCache(tipo) {
  try {
    var cache = CacheService.getScriptCache();
    var dados = cache.get(getCacheKey(tipo));
    if (dados) {
      Logger.log('>>> Cache HIT para: ' + tipo);
      return JSON.parse(dados);
    }
    Logger.log('>>> Cache MISS para: ' + tipo);
    return null;
  } catch (e) {
    Logger.log('>>> Erro ao ler cache: ' + e.toString());
    return null;
  }
}

/**
 * Salva dados no cache
 * Nota: CacheService tem limite de 100KB por item
 */
function saveToCache(tipo, dados, duracaoSegundos) {
  try {
    var cache = CacheService.getScriptCache();
    var jsonStr = JSON.stringify(dados);
    
    // Verifica se cabe no cache (limite ~100KB)
    if (jsonStr.length > 90000) {
      Logger.log('>>> Dados muito grandes para cache: ' + tipo + ' (' + jsonStr.length + ' chars)');
      return false;
    }
    
    cache.put(getCacheKey(tipo), jsonStr, duracaoSegundos || CONFIG.CACHE_DURATION);
    Logger.log('>>> Cache SALVO para: ' + tipo);
    return true;
  } catch (e) {
    Logger.log('>>> Erro ao salvar cache: ' + e.toString());
    return false;
  }
}

/**
 * Limpa o cache do usuário
 */
function limparCache() {
  try {
    var cache = CacheService.getScriptCache();
    var tipos = ['dados_iniciais', 'calendario', 'estatisticas'];
    tipos.forEach(function(tipo) {
      cache.remove(getCacheKey(tipo));
    });
    Logger.log('>>> Cache limpo');
    return { sucesso: true };
  } catch (e) {
    return { sucesso: false, mensagem: e.toString() };
  }
}

// ============================================
// CARREGAMENTO CONSOLIDADO (OTIMIZADO)
// ============================================

/**
 * FUNÇÃO PRINCIPAL OTIMIZADA
 * Lê a planilha UMA ÚNICA VEZ e retorna todos os dados necessários
 * para o carregamento inicial da aplicação
 */
function carregarDadosIniciais() {
  try {
    Logger.log('>>> carregarDadosIniciais: INÍCIO');
    var inicio = new Date().getTime();
    
    // 1. Verifica permissão
    var permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return { 
        erro: true, 
        mensagem: permissao.mensagem,
        permissao: permissao
      };
    }
    
    // 2. Tenta obter do cache
    var dadosCache = getFromCache('dados_iniciais');
    if (dadosCache) {
      dadosCache.permissao = permissao;
      dadosCache.doCache = true;
      Logger.log('>>> carregarDadosIniciais: Retornando do CACHE');
      return dadosCache;
    }
    
    // 3. Lê a planilha UMA ÚNICA VEZ
    var dados = lerDadosComPermissao();
    Logger.log('>>> Dados lidos: ' + dados.length + ' registros');
    
    if (!dados || dados.length === 0) {
      return {
        erro: false,
        permissao: permissao,
        estatisticas: criarEstatisticasVazias(permissao.perfil),
        prestadores: [],
        categorias: [],
        grupos: [],
        calendarioSemanal: {},
        ultimaAtualizacao: null,
        relacaoPrestadorCategoria: {}
      };
    }
    
    // 4. Processa tudo em UMA ÚNICA PASSAGEM
    var resultado = processarDadosConsolidados(dados, permissao.perfil);
    resultado.permissao = permissao;
    resultado.erro = false;
    
    // 5. Salva no cache
    saveToCache('dados_iniciais', resultado, CONFIG.CACHE_DURATION);
    
    var fim = new Date().getTime();
    Logger.log('>>> carregarDadosIniciais: FIM em ' + (fim - inicio) + 'ms');
    
    return resultado;
    
  } catch (error) {
    Logger.log('>>> ERRO em carregarDadosIniciais: ' + error.toString());
    return {
      erro: true,
      mensagem: 'Erro ao carregar dados: ' + error.toString()
    };
  }
}

// ============================================
// CARREGAMENTO MASTER - TUDO DE UMA VEZ
// ============================================

/**
 * FUNÇÃO MASTER: Carrega TODOS os dados necessários em UMA ÚNICA leitura
 * Retorna dados para: Ofertas, Distribuição, FPO e Teto
 */
function carregarTodosDados() {
  try {
    Logger.log('>>> carregarTodosDados: INÍCIO');
    var inicio = new Date().getTime();
    
    // 1. Verifica permissão
    var permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return { 
        erro: true, 
        mensagem: permissao.mensagem,
        permissao: permissao
      };
    }
    
    // 2. Lê a planilha principal UMA ÚNICA VEZ
    var dadosBrutos = lerDadosPlanilha();
    Logger.log('>>> Dados brutos lidos: ' + dadosBrutos.length + ' registros');
    
    // 3. Aplica filtro de permissão se necessário
    var dados = dadosBrutos;
    if (permissao.perfil === 'parcial') {
      dados = dadosBrutos.filter(function(d) {
        var local = d.Local;
        if (!local) return true;
        var localUpper = local.toString().toUpperCase().trim();
        return localUpper === 'NÃO' || localUpper === 'NAO';
      });
    }
    
    // 4. Lê dados auxiliares (FPO, DePara, Teto) - são pequenos, não impactam muito
    var dadosFpo = lerDadosFPO();
    var dePara = lerDePara();
    var tabelaTeto = lerTabelaTeto();
    
    // 5. Processa TUDO em uma única passagem otimizada
    var resultado = processarTodosDadosConsolidados(dados, dadosBrutos, dadosFpo, dePara, tabelaTeto, permissao);
    
    var fim = new Date().getTime();
    Logger.log('>>> carregarTodosDados: FIM em ' + (fim - inicio) + 'ms');
    
    return resultado;
    
  } catch (error) {
    Logger.log('>>> ERRO em carregarTodosDados: ' + error.toString());
    return {
      erro: true,
      mensagem: 'Erro ao carregar dados: ' + error.toString()
    };
  }
}

/**
 * Processa todos os dados em uma única passagem
 */
function processarTodosDadosConsolidados(dados, dadosBrutos, dadosFpo, dePara, tabelaTeto, permissao) {
  
  // ============ ESTRUTURAS COMPARTILHADAS ============
  var prestadoresSet = new Set();
  var categoriasSet = new Set();
  var gruposSet = new Set();
  var medicosSet = new Set();
  var relacaoPrestadorCategoria = {};
  var ultimaData = null;
  
  // Mapa de escalas para detectar compartilhadas
  var escalasMap = {};
  var escalasCompartilhadas = {};
  
  // ============ ESTRUTURAS PARA OFERTAS ============
  var stats = {
    totalOfertas: 0,
    vagasRede: 0,
    vagasRetorno: 0,
    vagasReserva: 0,
    agendaLocal: 0,
    agendaNaoLocal: 0,
    totalPrestadores: 0,
    totalCategorias: 0,
    totalMedicos: 0,
    perfil: permissao.perfil
  };
  var calendarioSemanal = {};
  
  // ============ ESTRUTURAS PARA DISTRIBUIÇÃO ============
  var distribuicaoMap = {};
  
  // ============ PRIMEIRA PASSAGEM: Coleta escalas ============
  for (var i = 0; i < dados.length; i++) {
    var d = dados[i];
    var escalaCodigo = d.escala_codigo;
    if (escalaCodigo) {
      if (!escalasMap[escalaCodigo]) {
        escalasMap[escalaCodigo] = [];
      }
      escalasMap[escalaCodigo].push(d.item_nome);
    }
  }
  
  // Identifica escalas compartilhadas
  var codigosEscala = Object.keys(escalasMap);
  for (var j = 0; j < codigosEscala.length; j++) {
    var codigo = codigosEscala[j];
    if (escalasMap[codigo].length > 1) {
      escalasCompartilhadas[codigo] = true;
    }
  }
  
  // ============ SEGUNDA PASSAGEM: Processa tudo ============
  for (var k = 0; k < dados.length; k++) {
    var row = dados[k];
    
    // Extrai valores uma vez
    var status = (row.escala_status || '').toString().toLowerCase().trim();
    var isAtivo = (status === 'ativo' || status === 'ativa');
    var unidadeNome = row.unidade_nome || '';
    var itemNome = row.item_nome || '';
    var procedimentoNome = row.procedimento_nome || '';
    var nomeMedico = row['Nome Médico'] || '';
    var diaSemana = row.escala_dia_semana || '';
    var local = (row.Local || '').toString().toUpperCase().trim();
    var isLocal = (local === 'SIM');
    
    var rede = parseFloat(row['Rede'] || 0);
    var retorno = parseFloat(row['Retorno '] || row['Retorno'] || 0);
    var reserva = parseFloat(row['Reserva'] || 0);
    var totalVagas = rede + retorno + reserva;
    
    // Coleta listas únicas
    if (unidadeNome) prestadoresSet.add(unidadeNome);
    if (itemNome) categoriasSet.add(itemNome);
    if (procedimentoNome) gruposSet.add(procedimentoNome);
    if (nomeMedico) medicosSet.add(nomeMedico);
    
    // Relação prestador -> categorias
    if (unidadeNome && itemNome) {
      if (!relacaoPrestadorCategoria[unidadeNome]) {
        relacaoPrestadorCategoria[unidadeNome] = new Set();
      }
      relacaoPrestadorCategoria[unidadeNome].add(itemNome);
    }
    
    // Data de extração
    var dataExtracao = row.data_extracao;
    if (dataExtracao) {
      var dataObj = parseDataExtracao(dataExtracao);
      if (dataObj && (!ultimaData || dataObj > ultimaData)) {
        ultimaData = dataObj;
      }
    }
    
    // ============ PROCESSA APENAS ATIVOS ============
    if (!isAtivo) continue;
    
    // --- ESTATÍSTICAS ---
    stats.vagasRede += rede;
    stats.vagasRetorno += retorno;
    stats.vagasReserva += reserva;
    stats.totalOfertas += totalVagas;
    
    if (isLocal) {
      stats.agendaLocal += totalVagas;
    } else {
      stats.agendaNaoLocal += totalVagas;
    }
    
    // --- DISTRIBUIÇÃO ---
    if (unidadeNome) {
      if (!distribuicaoMap[unidadeNome]) {
        distribuicaoMap[unidadeNome] = { nome: unidadeNome, local: 0, naoLocal: 0, total: 0 };
      }
      distribuicaoMap[unidadeNome].total += totalVagas;
      if (isLocal) {
        distribuicaoMap[unidadeNome].local += totalVagas;
      } else {
        distribuicaoMap[unidadeNome].naoLocal += totalVagas;
      }
    }
    
    // --- CALENDÁRIO ---
    if (diaSemana) {
      if (!calendarioSemanal[diaSemana]) {
        calendarioSemanal[diaSemana] = {
          diaSemana: diaSemana,
          diaExtenso: DIAS_SEMANA[diaSemana] || diaSemana,
          totalOfertas: 0,
          totalBloqueios: 0,
          agendaLocal: { total: 0, categorias: {} },
          agendaNaoLocal: { total: 0, categorias: {} }
        };
      }
      
      var cal = calendarioSemanal[diaSemana];
      cal.totalOfertas += totalVagas;
      
      var temBloqueio = (row.tem_afastamento_ativo || '').toString().toUpperCase().trim() === 'SIM';
      if (temBloqueio) {
        cal.totalBloqueios += 1;
      }
      
      var tipoAgenda = isLocal ? 'agendaLocal' : 'agendaNaoLocal';
      cal[tipoAgenda].total += totalVagas;
      
      if (itemNome) {
        if (!cal[tipoAgenda].categorias[itemNome]) {
          cal[tipoAgenda].categorias[itemNome] = {
            nome: itemNome,
            quantidade: 0,
            prestadores: {}
          };
        }
        
        var catObj = cal[tipoAgenda].categorias[itemNome];
        catObj.quantidade += totalVagas;
        
        if (unidadeNome) {
          if (!catObj.prestadores[unidadeNome]) {
            catObj.prestadores[unidadeNome] = {
              nome: unidadeNome,
              quantidade: 0,
              vagasRede: 0,
              vagasRetorno: 0,
              vagasReserva: 0,
              medicosTexto: ''
            };
          }
          
          var prestObj = catObj.prestadores[unidadeNome];
          prestObj.quantidade += totalVagas;
          prestObj.vagasRede += rede;
          prestObj.vagasRetorno += retorno;
          prestObj.vagasReserva += reserva;
          
          if (nomeMedico) {
            var horario = formatarHorario(row.escala_horario);
            var escCodigo = row.escala_codigo || 'S/N';
            var isCompartilhada = escalasCompartilhadas[escCodigo] || false;
            var bloqueioMark = temBloqueio ? ' 🚫 BLOQUEADA' : '';
            var compartilhadoMark = isCompartilhada ? ' ⚠️ AGRUPADA' : '';
            
            var medicoInfo = 'Escala ' + escCodigo + compartilhadoMark + bloqueioMark + ' | ' + nomeMedico + ' - ' + horario + ' (R:' + rede + ', Ret:' + retorno + ', Res:' + reserva + ')';
            
            if (prestObj.medicosTexto) {
              prestObj.medicosTexto += ' | ' + medicoInfo;
            } else {
              prestObj.medicosTexto = medicoInfo;
            }
          }
        }
      }
    }
  }
  
  // ============ FINALIZA ESTRUTURAS ============
  
  // Converte Sets para arrays ordenados
  var prestadoresArray = Array.from(prestadoresSet).sort();
  var categoriasArray = Array.from(categoriasSet).sort();
  var gruposArray = Array.from(gruposSet).sort();
  
  stats.totalPrestadores = prestadoresArray.length;
  stats.totalCategorias = categoriasArray.length;
  stats.totalMedicos = medicosSet.size;
  
  // Arredonda estatísticas
  stats.totalOfertas = Math.round(stats.totalOfertas);
  stats.vagasRede = Math.round(stats.vagasRede);
  stats.vagasRetorno = Math.round(stats.vagasRetorno);
  stats.vagasReserva = Math.round(stats.vagasReserva);
  stats.agendaLocal = Math.round(stats.agendaLocal);
  stats.agendaNaoLocal = Math.round(stats.agendaNaoLocal);
  
  // Converte calendário
  var calendarioFinal = converterCalendarioParaArrays(calendarioSemanal);
  
  // Converte relação prestador->categorias
  var relacaoFinal = {};
  var prestKeys = Object.keys(relacaoPrestadorCategoria);
  for (var p = 0; p < prestKeys.length; p++) {
    var prestNome = prestKeys[p];
    relacaoFinal[prestNome] = Array.from(relacaoPrestadorCategoria[prestNome]).sort();
  }
  
  // Formata última atualização
  var ultimaAtualizacaoStr = null;
  if (ultimaData) {
    var dia = String(ultimaData.getDate()).padStart(2, '0');
    var mes = String(ultimaData.getMonth() + 1).padStart(2, '0');
    var ano = ultimaData.getFullYear();
    ultimaAtualizacaoStr = dia + '/' + mes + '/' + ano;
  }
  
  // Converte distribuição para array
  var distribuicaoArray = Object.values(distribuicaoMap)
    .filter(function(p) { return p.total > 0; })
    .map(function(p) {
      return {
        nome: p.nome,
        local: Math.round(p.local),
        naoLocal: Math.round(p.naoLocal),
        total: Math.round(p.total)
      };
    })
    .sort(function(a, b) { return a.nome.localeCompare(b.nome); });
  
  // ============ RETORNA TUDO ============
  return {
    erro: false,
    permissao: permissao,
    
    // Dados para aba Ofertas
    estatisticas: stats,
    prestadores: prestadoresArray,
    categorias: categoriasArray,
    grupos: gruposArray,
    calendarioSemanal: calendarioFinal,
    ultimaAtualizacao: ultimaAtualizacaoStr,
    relacaoPrestadorCategoria: relacaoFinal,
    
    // Dados para aba Distribuição
    distribuicao: distribuicaoArray,
    
    // Flags para indicar que dados auxiliares estão disponíveis
    temDadosFpo: dadosFpo.length > 0,
    temDadosTeto: Object.keys(tabelaTeto).length > 0
  };
}


/**
 * Processa todos os dados em uma única passagem
 */
function processarDadosConsolidados(dados, perfil) {
  // Sets para listas únicas
  var prestadoresSet = new Set();
  var categoriasSet = new Set();
  var gruposSet = new Set();
  
  // Mapa para relação prestador -> categorias
  var relacaoPrestadorCategoria = {};
  
  // Estatísticas
  var stats = {
    totalOfertas: 0,
    vagasRede: 0,
    vagasRetorno: 0,
    vagasReserva: 0,
    agendaLocal: 0,
    agendaNaoLocal: 0,
    totalPrestadores: 0,
    totalCategorias: 0,
    totalMedicos: 0,
    perfil: perfil
  };
  
  // Calendário semanal
  var calendarioSemanal = {};
  
  // Mapa de escalas para detectar compartilhadas
  var escalasMap = {};
  
  // Mapa de médicos únicos
  var medicosSet = new Set();
  
  // Última atualização
  var ultimaData = null;
  
  // PRIMEIRA PASSAGEM: Coleta escalas para detectar compartilhadas
  for (var i = 0; i < dados.length; i++) {
    var d = dados[i];
    var escalaCodigo = d.escala_codigo;
    if (escalaCodigo) {
      if (!escalasMap[escalaCodigo]) {
        escalasMap[escalaCodigo] = [];
      }
      escalasMap[escalaCodigo].push(d.item_nome);
    }
  }
  
  // Identifica escalas compartilhadas
  var escalasCompartilhadas = {};
  var codigosEscala = Object.keys(escalasMap);
  for (var j = 0; j < codigosEscala.length; j++) {
    var codigo = codigosEscala[j];
    if (escalasMap[codigo].length > 1) {
      escalasCompartilhadas[codigo] = true;
    }
  }
  
  // SEGUNDA PASSAGEM: Processa tudo
  for (var k = 0; k < dados.length; k++) {
    var row = dados[k];
    
    // Extrai valores uma vez
    var status = (row.escala_status || '').toString().toLowerCase().trim();
    var isAtivo = (status === 'ativo' || status === 'ativa');
    var unidadeNome = row.unidade_nome || '';
    var itemNome = row.item_nome || '';
    var procedimentoNome = row.procedimento_nome || '';
    var nomeMedico = row['Nome Médico'] || '';
    var diaSemana = row.escala_dia_semana || '';
    var local = (row.Local || '').toString().toUpperCase().trim();
    var isLocal = (local === 'SIM');
    
    var rede = parseFloat(row['Rede'] || 0);
    var retorno = parseFloat(row['Retorno '] || row['Retorno'] || 0);
    var reserva = parseFloat(row['Reserva'] || 0);
    var totalVagas = rede + retorno + reserva;
    
    // Coleta listas únicas (todos os registros, não só ativos)
    if (unidadeNome) prestadoresSet.add(unidadeNome);
    if (itemNome) categoriasSet.add(itemNome);
    if (procedimentoNome) gruposSet.add(procedimentoNome);
    if (nomeMedico) medicosSet.add(nomeMedico);
    
    // Monta relação prestador -> categorias
    if (unidadeNome && itemNome) {
      if (!relacaoPrestadorCategoria[unidadeNome]) {
        relacaoPrestadorCategoria[unidadeNome] = new Set();
      }
      relacaoPrestadorCategoria[unidadeNome].add(itemNome);
    }
    
    // Verifica data de extração
    var dataExtracao = row.data_extracao;
    if (dataExtracao) {
      var dataObj = parseDataExtracao(dataExtracao);
      if (dataObj && (!ultimaData || dataObj > ultimaData)) {
        ultimaData = dataObj;
      }
    }
    
    // Processa apenas ativos para estatísticas e calendário
    if (!isAtivo) continue;
    
    // Estatísticas
    stats.vagasRede += rede;
    stats.vagasRetorno += retorno;
    stats.vagasReserva += reserva;
    stats.totalOfertas += totalVagas;
    
    if (isLocal) {
      stats.agendaLocal += totalVagas;
    } else {
      stats.agendaNaoLocal += totalVagas;
    }
    
    // Calendário semanal
    if (diaSemana) {
      if (!calendarioSemanal[diaSemana]) {
        calendarioSemanal[diaSemana] = {
          diaSemana: diaSemana,
          diaExtenso: DIAS_SEMANA[diaSemana] || diaSemana,
          totalOfertas: 0,
          totalBloqueios: 0,
          agendaLocal: { total: 0, categorias: {} },
          agendaNaoLocal: { total: 0, categorias: {} }
        };
      }
      
      var cal = calendarioSemanal[diaSemana];
      cal.totalOfertas += totalVagas;
      
      // Bloqueios
      var temBloqueio = (row.tem_afastamento_ativo || '').toString().toUpperCase().trim() === 'SIM';
      if (temBloqueio) {
        cal.totalBloqueios += 1;
      }
      
      // Tipo de agenda
      var tipoAgenda = isLocal ? 'agendaLocal' : 'agendaNaoLocal';
      cal[tipoAgenda].total += totalVagas;
      
      // Categorias dentro do dia
      if (itemNome) {
        if (!cal[tipoAgenda].categorias[itemNome]) {
          cal[tipoAgenda].categorias[itemNome] = {
            nome: itemNome,
            quantidade: 0,
            prestadores: {}
          };
        }
        
        var catObj = cal[tipoAgenda].categorias[itemNome];
        catObj.quantidade += totalVagas;
        
        // Prestadores dentro da categoria
        if (unidadeNome) {
          if (!catObj.prestadores[unidadeNome]) {
            catObj.prestadores[unidadeNome] = {
              nome: unidadeNome,
              quantidade: 0,
              vagasRede: 0,
              vagasRetorno: 0,
              vagasReserva: 0,
              medicosTexto: ''
            };
          }
          
          var prestObj = catObj.prestadores[unidadeNome];
          prestObj.quantidade += totalVagas;
          prestObj.vagasRede += rede;
          prestObj.vagasRetorno += retorno;
          prestObj.vagasReserva += reserva;
          
          // Médico
          if (nomeMedico) {
            var horario = formatarHorario(row.escala_horario);
            var escCodigo = row.escala_codigo || 'S/N';
            var isCompartilhada = escalasCompartilhadas[escCodigo] || false;
            var bloqueioMark = temBloqueio ? ' 🚫 BLOQUEADA' : '';
            var compartilhadoMark = isCompartilhada ? ' ⚠️ AGRUPADA' : '';
            
            var medicoInfo = 'Escala ' + escCodigo + compartilhadoMark + bloqueioMark + ' | ' + nomeMedico + ' - ' + horario + ' (R:' + rede + ', Ret:' + retorno + ', Res:' + reserva + ')';
            
            if (prestObj.medicosTexto) {
              prestObj.medicosTexto += ' | ' + medicoInfo;
            } else {
              prestObj.medicosTexto = medicoInfo;
            }
          }
        }
      }
    }
  }
  
  // Converte Sets para arrays ordenados
  var prestadoresArray = Array.from(prestadoresSet).sort();
  var categoriasArray = Array.from(categoriasSet).sort();
  var gruposArray = Array.from(gruposSet).sort();
  
  // Atualiza contadores
  stats.totalPrestadores = prestadoresArray.length;
  stats.totalCategorias = categoriasArray.length;
  stats.totalMedicos = medicosSet.size;
  
  // Arredonda valores
  stats.totalOfertas = Math.round(stats.totalOfertas);
  stats.vagasRede = Math.round(stats.vagasRede);
  stats.vagasRetorno = Math.round(stats.vagasRetorno);
  stats.vagasReserva = Math.round(stats.vagasReserva);
  stats.agendaLocal = Math.round(stats.agendaLocal);
  stats.agendaNaoLocal = Math.round(stats.agendaNaoLocal);
  
  // Converte calendário para formato final
  var calendarioFinal = converterCalendarioParaArrays(calendarioSemanal);
  
  // Converte relação para formato serializável (Set -> Array)
  var relacaoFinal = {};
  var prestKeys = Object.keys(relacaoPrestadorCategoria);
  for (var p = 0; p < prestKeys.length; p++) {
    var prestNome = prestKeys[p];
    relacaoFinal[prestNome] = Array.from(relacaoPrestadorCategoria[prestNome]).sort();
  }
  
  // Formata última atualização
  var ultimaAtualizacaoStr = null;
  if (ultimaData) {
    var dia = String(ultimaData.getDate()).padStart(2, '0');
    var mes = String(ultimaData.getMonth() + 1).padStart(2, '0');
    var ano = ultimaData.getFullYear();
    ultimaAtualizacaoStr = dia + '/' + mes + '/' + ano;
  }
  
  return {
    estatisticas: stats,
    prestadores: prestadoresArray,
    categorias: categoriasArray,
    grupos: gruposArray,
    calendarioSemanal: calendarioFinal,
    ultimaAtualizacao: ultimaAtualizacaoStr,
    relacaoPrestadorCategoria: relacaoFinal
  };
}

/**
 * Converte o calendário de objetos para arrays (para serialização)
 */
function converterCalendarioParaArrays(calendario) {
  var resultado = {};
  var dias = Object.keys(calendario);
  
  for (var i = 0; i < dias.length; i++) {
    var dia = dias[i];
    var calDia = calendario[dia];
    
    // Arredonda totais
    calDia.totalOfertas = Math.round(calDia.totalOfertas);
    calDia.agendaLocal.total = Math.round(calDia.agendaLocal.total);
    calDia.agendaNaoLocal.total = Math.round(calDia.agendaNaoLocal.total);
    
    // Converte categorias de objeto para array
    calDia.agendaLocal.categorias = converterCategoriasParaArray(calDia.agendaLocal.categorias);
    calDia.agendaNaoLocal.categorias = converterCategoriasParaArray(calDia.agendaNaoLocal.categorias);
    
    resultado[dia] = calDia;
  }
  
  return resultado;
}

/**
 * Converte objeto de categorias para array
 */
function converterCategoriasParaArray(categoriasObj) {
  var resultado = [];
  var catNomes = Object.keys(categoriasObj);
  
  for (var i = 0; i < catNomes.length; i++) {
    var catNome = catNomes[i];
    var cat = categoriasObj[catNome];
    
    // Converte prestadores para array
    var prestadoresArray = [];
    var prestNomes = Object.keys(cat.prestadores);
    
    for (var j = 0; j < prestNomes.length; j++) {
      var prestNome = prestNomes[j];
      var prest = cat.prestadores[prestNome];
      
      prestadoresArray.push({
        nome: prest.nome,
        quantidade: Math.round(prest.quantidade),
        vagasRede: Math.round(prest.vagasRede),
        vagasRetorno: Math.round(prest.vagasRetorno),
        vagasReserva: Math.round(prest.vagasReserva),
        medicosTexto: prest.medicosTexto || 'Nenhum médico informado'
      });
    }
    
    resultado.push({
      nome: cat.nome,
      quantidade: Math.round(cat.quantidade),
      prestadores: prestadoresArray
    });
  }
  
  return resultado;
}

/**
 * Cria objeto de estatísticas vazio
 */
function criarEstatisticasVazias(perfil) {
  return {
    totalOfertas: 0,
    vagasRede: 0,
    vagasRetorno: 0,
    vagasReserva: 0,
    totalPrestadores: 0,
    totalCategorias: 0,
    totalMedicos: 0,
    agendaLocal: 0,
    agendaNaoLocal: 0,
    perfil: perfil
  };
}

/**
 * Parse de data de extração
 */
function parseDataExtracao(dataExtracao) {
  try {
    if (typeof dataExtracao === 'string') {
      var partesDateTime = dataExtracao.split(' ');
      var partesData = partesDateTime[0].split('-');
      if (partesData.length === 3) {
        return new Date(partesData[0], partesData[1] - 1, partesData[2]);
      }
    } else if (dataExtracao instanceof Date) {
      return dataExtracao;
    }
  } catch (e) {
    // Ignora erros de parsing
  }
  return null;
}


// ============================================
// FUNÇÕES DE CONTROLE DE ACESSO
// ============================================

/**
 * Obtém o email do usuário atual
 */
function getUsuarioAtual() {
  try {
    const email = Session.getActiveUser().getEmail();
    Logger.log('>>> Email do usuário: ' + email);
    return email ? email.toLowerCase().trim() : '';
  } catch (error) {
    Logger.log('>>> ERRO ao obter email: ' + error.toString());
    return '';
  }
}

/**
 * Verifica as permissões do usuário atual
 * Retorna: { autorizado: boolean, perfil: 'total'|'parcial'|null, nome: string, email: string }
 */
function verificarPermissao() {
  try {
    Logger.log('>>> verificarPermissao: INÍCIO');
    
    const emailUsuario = getUsuarioAtual();
    Logger.log('>>> Email do usuário: ' + emailUsuario);
    
    if (!emailUsuario) {
      Logger.log('>>> ERRO: Não foi possível obter o email do usuário');
      return {
        autorizado: false,
        perfil: null,
        nome: '',
        email: '',
        mensagem: 'Não foi possível identificar seu email. Verifique se você está logado com uma conta Google.'
      };
    }
    
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheetPermissoes = ss.getSheetByName(CONFIG.PERMISSOES_SHEET);
    
    if (!sheetPermissoes) {
      Logger.log('>>> ERRO: Aba de permissões não encontrada!');
      return {
        autorizado: false,
        perfil: null,
        nome: '',
        email: emailUsuario,
        mensagem: 'Sistema de permissões não configurado. Entre em contato com o administrador.'
      };
    }
    
    const dados = sheetPermissoes.getDataRange().getValues();
    Logger.log('>>> Permissões carregadas: ' + (dados.length - 1) + ' registros');
    
    // Pula o cabeçalho (primeira linha)
    for (let i = 1; i < dados.length; i++) {
      const emailCadastrado = (dados[i][0] || '').toString().toLowerCase().trim();
      const perfil = (dados[i][1] || '').toString().toLowerCase().trim();
      const nome = (dados[i][2] || '').toString().trim();
      
      if (emailCadastrado === emailUsuario) {
        Logger.log('>>> Usuário encontrado! Perfil: ' + perfil);
        return {
          autorizado: true,
          perfil: perfil === 'total' ? 'total' : 'parcial',
          nome: nome || emailUsuario,
          email: emailUsuario,
          mensagem: ''
        };
      }
    }
    
    // Usuário não encontrado na lista
    Logger.log('>>> Usuário NÃO encontrado na lista de permissões');
    return {
      autorizado: false,
      perfil: null,
      nome: '',
      email: emailUsuario,
      mensagem: 'Seu email (' + emailUsuario + ') não está autorizado a acessar este sistema. Entre em contato com o administrador.'
    };
    
  } catch (error) {
    Logger.log('>>> ERRO em verificarPermissao: ' + error.toString());
    return {
      autorizado: false,
      perfil: null,
      nome: '',
      email: '',
      mensagem: 'Erro ao verificar permissões: ' + error.toString()
    };
  }
}

/**
 * Retorna informações do usuário para o frontend
 */
function getInfoUsuario() {
  return verificarPermissao();
}

// ============================================
// FUNÇÕES DE INTERFACE WEB
// ============================================

function doGet() {
  return HtmlService.createTemplateFromFile('Index')
    .evaluate()
    .setTitle(CONFIG.APP_NAME)
    .setFaviconUrl('https://img.icons8.com/color/48/000000/calendar.png')
    .addMetaTag('viewport', 'width=device-width, initial-scale=1')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

function include(filename) {
  return HtmlService.createHtmlOutputFromFile(filename).getContent();
}

// ============================================
// FUNÇÕES UTILITÁRIAS
// ============================================

/**
 * Formata um valor de horário para o formato HH:MM
 * Lida com objetos Date do Google Sheets e strings
 */
function formatarHorario(valor) {
  if (!valor) {
    return 'Não informado';
  }
  
  if (valor instanceof Date) {
    return Utilities.formatDate(valor, Session.getScriptTimeZone(), 'HH:mm');
  }
  
  if (typeof valor === 'string') {
    valor = valor.trim();
    if (/^\d{1,2}:\d{2}$/.test(valor)) {
      return valor;
    }
    if (/^\d{1,2}:\d{2}:\d{2}$/.test(valor)) {
      return valor.substring(0, 5);
    }
    try {
      const data = new Date(valor);
      if (!isNaN(data.getTime())) {
        const horas = String(data.getHours()).padStart(2, '0');
        const minutos = String(data.getMinutes()).padStart(2, '0');
        return horas + ':' + minutos;
      }
    } catch (e) {
    }
    return valor;
  }
  
  if (typeof valor === 'number') {
    const totalMinutos = Math.round(valor * 24 * 60);
    const horas = Math.floor(totalMinutos / 60) % 24;
    const minutos = totalMinutos % 60;
    return String(horas).padStart(2, '0') + ':' + String(minutos).padStart(2, '0');
  }
  
  return String(valor);
}   // <-- FECHA AQUI formatarHorario

/**
 * Formata uma data de bloqueio para exibição
 */
function formatarDataBloqueio(valor) {   // <-- COMEÇA AQUI como função SEPARADA
  if (!valor) return '';
  
  if (valor instanceof Date) {
    return Utilities.formatDate(valor, Session.getScriptTimeZone(), 'dd/MM/yyyy');
  }
  
  if (typeof valor === 'string') {
    valor = valor.trim();
    if (/^\d{2}\/\d{2}\/\d{4}$/.test(valor)) {
      return valor;
    }
    if (/^\d{4}-\d{2}-\d{2}/.test(valor)) {
      const partes = valor.substring(0, 10).split('-');
      return partes[2] + '/' + partes[1] + '/' + partes[0];
    }
    return valor;
  }
  
  if (typeof valor === 'number') {
    const data = new Date((valor - 25569) * 86400 * 1000);
    const dia = String(data.getDate()).padStart(2, '0');
    const mes = String(data.getMonth() + 1).padStart(2, '0');
    const ano = data.getFullYear();
    return dia + '/' + mes + '/' + ano;
  }
  
  return String(valor);
}

// ============================================
// FUNÇÕES DE LEITURA DE DADOS
// ============================================

function lerDadosPlanilha() {
  try {
    Logger.log('>>> lerDadosPlanilha: INÍCIO');
    
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName(CONFIG.SHEET_NAME);
    
    if (!sheet) {
      throw new Error(`Aba "${CONFIG.SHEET_NAME}" não encontrada!`);
    }
    
    const range = sheet.getDataRange();
    const values = range.getValues();
    const displayValues = range.getDisplayValues();
    
    Logger.log('>>> lerDadosPlanilha: ' + values.length + ' linhas (incluindo cabeçalho)');
    
    if (values.length <= 1) {
      Logger.log('>>> lerDadosPlanilha: SEM DADOS!');
      return [];
    }
    
    const headers = values[0];
    Logger.log('>>> lerDadosPlanilha: Cabeçalhos = ' + headers.join(', '));
    
    const dados = [];
    for (let i = 1; i < values.length; i++) {
      const row = {};
      for (let j = 0; j < headers.length; j++) {
        // Se for a coluna escala_horario, usa o valor de exibição
        if (headers[j] === 'escala_horario') {
          row[headers[j]] = displayValues[i][j];
        } else {
          row[headers[j]] = values[i][j];
        }
      }
      dados.push(row);
    }
    
    Logger.log('>>> lerDadosPlanilha: FIM - ' + dados.length + ' registros');
    return dados;
  } catch (error) {
    Logger.log('>>> lerDadosPlanilha: ERRO - ' + error.toString());
    throw error;
  }
}

/**
 * NOVA FUNÇÃO: Lê dados aplicando filtro de permissão
 * Se perfil = 'parcial', retorna apenas dados de Agenda NÃO Local
 */
function lerDadosComPermissao() {
  try {
    const permissao = verificarPermissao();
    
    if (!permissao.autorizado) {
      Logger.log('>>> Usuário não autorizado!');
      return [];
    }
    
    let dados = lerDadosPlanilha();
    
    // Se perfil é parcial, filtra apenas Agenda Não Local
    if (permissao.perfil === 'parcial') {
      Logger.log('>>> Aplicando filtro de perfil PARCIAL (somente Agenda Não Local)');
      dados = dados.filter(d => {
        const local = d.Local;
        if (!local) return true; // Se não tem informação, inclui
        const localUpper = local.toString().toUpperCase().trim();
        return localUpper === 'NÃO' || localUpper === 'NAO';
      });
      Logger.log('>>> Dados após filtro de permissão: ' + dados.length);
    }
    
    return dados;
  } catch (error) {
    Logger.log('>>> ERRO em lerDadosComPermissao: ' + error.toString());
    return [];
  }
}

// ============================================
// FUNÇÕES DE ESTATÍSTICAS
// ============================================

function getEstatisticas() {
  try {
    Logger.log('>>> getEstatisticas: INÍCIO');
    
    const permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return { erro: true, mensagem: permissao.mensagem };
    }
    
    const dados = lerDadosComPermissao();
    Logger.log('>>> getEstatisticas: Total de dados = ' + dados.length);
    
    if (dados.length === 0) {
      return {
        totalOfertas: 0,
        vagasRede: 0,
        vagasRetorno: 0,
        vagasReserva: 0,
        totalPrestadores: 0,
        totalCategorias: 0,
        totalMedicos: 0,
        agendaLocal: 0,
        agendaNaoLocal: 0,
        perfil: permissao.perfil
      };
    }
    
    // Contadores gerais
    let totalVagas = 0;
    let vagasRede = 0;
    let vagasRetorno = 0;
    let vagasReserva = 0;
    
    // Contadores por tipo de agenda
    let vagasAgendaLocal = 0;
    let vagasAgendaNaoLocal = 0;
    
    const prestadoresSet = new Set();
    const categoriasSet = new Set();
    const medicosSet = new Set();
    
    // Processa em um único loop
    dados.forEach(d => {
      const status = d.escala_status;
      if (!status) return;
      
      const statusLower = status.toString().toLowerCase().trim();
      if (statusLower !== 'ativo' && statusLower !== 'ativa') return;
      
      // Soma vagas
      const rede = parseFloat(d['Rede'] || 0);
      const retorno = parseFloat(d['Retorno '] || d['Retorno'] || 0);
      const reserva = parseFloat(d['Reserva'] || 0);
      
      vagasRede += rede;
      vagasRetorno += retorno;
      vagasReserva += reserva;
      
      const totalVagasRegistro = rede + retorno + reserva;
      totalVagas += totalVagasRegistro;
      
      // Verifica tipo de agenda
      const local = d.Local;
      if (local) {
        const localUpper = local.toString().toUpperCase().trim();
        if (localUpper === 'SIM') {
          vagasAgendaLocal += totalVagasRegistro;
        } else if (localUpper === 'NÃO' || localUpper === 'NAO') {
          vagasAgendaNaoLocal += totalVagasRegistro;
        }
      }
      
      // Adiciona aos sets
      if (d.unidade_nome) prestadoresSet.add(d.unidade_nome);
      if (d.item_nome) categoriasSet.add(d.item_nome);
      if (d['Nome Médico']) medicosSet.add(d['Nome Médico']);
    });
    
    const resultado = {
      totalOfertas: Math.round(totalVagas),
      vagasRede: Math.round(vagasRede),
      vagasRetorno: Math.round(vagasRetorno),
      vagasReserva: Math.round(vagasReserva),
      totalPrestadores: prestadoresSet.size,
      totalCategorias: categoriasSet.size,
      totalMedicos: medicosSet.size,
      agendaLocal: Math.round(vagasAgendaLocal),
      agendaNaoLocal: Math.round(vagasAgendaNaoLocal),
      perfil: permissao.perfil
    };
    
    Logger.log('>>> getEstatisticas: FIM - Total=' + resultado.totalOfertas);
    return resultado;
    
  } catch (error) {
    Logger.log('>>> getEstatisticas: ERRO - ' + error.toString());
    return {
      totalOfertas: 0,
      vagasRede: 0,
      vagasRetorno: 0,
      vagasReserva: 0,
      totalPrestadores: 0,
      totalCategorias: 0,
      totalMedicos: 0,
      agendaLocal: 0,
      agendaNaoLocal: 0,
      perfil: null
    };
  }
}

// ============================================
// FUNÇÕES DE CALENDÁRIO
// ============================================

/**
 * VERSÃO COM CONTROLE DE ACESSO
 */
function getDadosCalendario(mesAno) {
  try {
    Logger.log('=== getDadosCalendario COM CONTROLE DE ACESSO ===');
    
    const permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return { erro: true, mensagem: permissao.mensagem };
    }
    
    // 1. Ler dados COM PERMISSÃO
    const dados = lerDadosComPermissao();
    Logger.log('Total de dados (com permissão): ' + dados.length);
    
    if (!dados || dados.length === 0) {
      return {};
    }
    
    // 2. Detectar escalas compartilhadas
    const escalasMap = {};
    dados.forEach(d => {
      const escalaCodigo = d.escala_codigo;
      if (escalaCodigo) {
        if (!escalasMap[escalaCodigo]) {
          escalasMap[escalaCodigo] = [];
        }
        escalasMap[escalaCodigo].push(d.item_nome);
      }
    });
    
    const escalasCompartilhadas = new Set();
    Object.keys(escalasMap).forEach(codigo => {
      if (escalasMap[codigo].length > 1) {
        escalasCompartilhadas.add(codigo);
      }
    });
    
    // 3. Filtrar ativos
    const ativos = [];
    for (let i = 0; i < dados.length; i++) {
      const d = dados[i];
      if (d.escala_status) {
        const status = d.escala_status.toString().toLowerCase().trim();
        if (status === 'ativo' || status === 'ativa') {
          ativos.push(d);
        }
      }
    }
    
    Logger.log('Dados ativos: ' + ativos.length);
    
    if (ativos.length === 0) {
      return {};
    }
    
    // 4. Processar por dia
    const calendario = {};
    
    for (let i = 0; i < ativos.length; i++) {
      const row = ativos[i];
      const dia = row.escala_dia_semana;
      
      if (!dia) continue;
      
      if (!calendario[dia]) {
        calendario[dia] = {
          diaSemana: dia,
          diaExtenso: DIAS_SEMANA[dia] || dia,
          totalOfertas: 0,
          totalBloqueios: 0,
          agendaLocal: {
            total: 0,
            categorias: {}
          },
          agendaNaoLocal: {
            total: 0,
            categorias: {}
          }
        };
      }
      
      const rede = parseFloat(row['Rede'] || 0);
      const retorno = parseFloat(row['Retorno '] || row['Retorno'] || 0);
      const reserva = parseFloat(row['Reserva'] || 0);
      const totalVagas = rede + retorno + reserva;
      
      calendario[dia].totalOfertas += totalVagas;

      // Verifica se tem bloqueio ativo
      const temBloqueio = (row.tem_afastamento_ativo || '').toString().toUpperCase().trim() === 'SIM';
      if (temBloqueio) {
        calendario[dia].totalBloqueios += 1;
      }

      // Determina se é agenda local ou não
      const local = row.Local;
      
      let isAgendaLocal = false;
      
      if (local) {
        const localUpper = local.toString().toUpperCase().trim();
        isAgendaLocal = (localUpper === 'SIM');
      }
      
      // Seleciona a estrutura correta (local ou não local)
      const tipoAgenda = isAgendaLocal ? 'agendaLocal' : 'agendaNaoLocal';
      calendario[dia][tipoAgenda].total += totalVagas;
      
      const categoria = row.item_nome;
      if (!categoria) continue;
      
      if (!calendario[dia][tipoAgenda].categorias[categoria]) {
        calendario[dia][tipoAgenda].categorias[categoria] = {
          nome: categoria,
          quantidade: 0,
          prestadores: {}
        };
      }
      
      calendario[dia][tipoAgenda].categorias[categoria].quantidade += totalVagas;
      
      const prestador = row.unidade_nome;
      if (!prestador) continue;
      
      if (!calendario[dia][tipoAgenda].categorias[categoria].prestadores[prestador]) {
        calendario[dia][tipoAgenda].categorias[categoria].prestadores[prestador] = {
          nome: prestador,
          quantidade: 0,
          vagasRede: 0,
          vagasRetorno: 0,
          vagasReserva: 0,
          medicosTexto: ''
        };
      }
      
      const prest = calendario[dia][tipoAgenda].categorias[categoria].prestadores[prestador];
      prest.quantidade += totalVagas;
      prest.vagasRede += rede;
      prest.vagasRetorno += retorno;
      prest.vagasReserva += reserva;
      
      // Médico como STRING + escala_codigo + compartilhamento + bloqueio
      const medico = row['Nome Médico'];
      const horarioRaw = row.escala_horario;
      const horario = formatarHorario(horarioRaw);
      const escalaCodigo = row.escala_codigo || 'S/N';
      const isCompartilhada = escalasCompartilhadas.has(escalaCodigo);

      // Verifica bloqueio para exibição no médico
      const temBloqueioMedico = (row.tem_afastamento_ativo || '').toString().toUpperCase().trim() === 'SIM';
      const dtInicioBloqueio = row.dt_inicio_afastamento ? formatarDataBloqueio(row.dt_inicio_afastamento) : '';
      const dtFimBloqueio = row.dt_fim_afastamento ? formatarDataBloqueio(row.dt_fim_afastamento) : '';
      const codigoBloqueio = row.codigo_afastamento || '';

      if (medico) {
        const compartilhadoMark = isCompartilhada ? ' ⚠️ AGRUPADA' : '';
        const bloqueioMark = temBloqueioMedico ? ` 🚫 BLOQUEADA (${dtInicioBloqueio} a ${dtFimBloqueio})` : '';
        const medicoInfo = `Escala ${escalaCodigo}${compartilhadoMark}${bloqueioMark} | ${medico} - ${horario} (R:${rede}, Ret:${retorno}, Res:${reserva})`;
        if (prest.medicosTexto) {
          prest.medicosTexto += ' | ' + medicoInfo;
        } else {
          prest.medicosTexto = medicoInfo;
        }
      }
    }
    
    
    // 5. Converter em arrays
    const diasKeys = Object.keys(calendario);
    for (let i = 0; i < diasKeys.length; i++) {
      const dia = diasKeys[i];
      
      calendario[dia].totalOfertas = Math.round(calendario[dia].totalOfertas);
      calendario[dia].agendaLocal.total = Math.round(calendario[dia].agendaLocal.total);
      calendario[dia].agendaNaoLocal.total = Math.round(calendario[dia].agendaNaoLocal.total);
      
      // Processar agenda local
      const categoriasLocalArray = [];
      const catLocalKeys = Object.keys(calendario[dia].agendaLocal.categorias);
      
      for (let j = 0; j < catLocalKeys.length; j++) {
        const catNome = catLocalKeys[j];
        const cat = calendario[dia].agendaLocal.categorias[catNome];
        
        const prestadoresArray = [];
        const prestKeys = Object.keys(cat.prestadores);
        
        for (let k = 0; k < prestKeys.length; k++) {
          const prestNome = prestKeys[k];
          const prest = cat.prestadores[prestNome];
          
          prestadoresArray.push({
            nome: prest.nome,
            quantidade: Math.round(prest.quantidade),
            vagasRede: Math.round(prest.vagasRede),
            vagasRetorno: Math.round(prest.vagasRetorno),
            vagasReserva: Math.round(prest.vagasReserva),
            medicosTexto: prest.medicosTexto || 'Nenhum médico informado'
          });
        }
        
        categoriasLocalArray.push({
          nome: cat.nome,
          quantidade: Math.round(cat.quantidade),
          prestadores: prestadoresArray
        });
      }
      
      calendario[dia].agendaLocal.categorias = categoriasLocalArray;
      
      // Processar agenda não local
      const categoriasNaoLocalArray = [];
      const catNaoLocalKeys = Object.keys(calendario[dia].agendaNaoLocal.categorias);
      
      for (let j = 0; j < catNaoLocalKeys.length; j++) {
        const catNome = catNaoLocalKeys[j];
        const cat = calendario[dia].agendaNaoLocal.categorias[catNome];
        
        const prestadoresArray = [];
        const prestKeys = Object.keys(cat.prestadores);
        
        for (let k = 0; k < prestKeys.length; k++) {
          const prestNome = prestKeys[k];
          const prest = cat.prestadores[prestNome];
          
          prestadoresArray.push({
            nome: prest.nome,
            quantidade: Math.round(prest.quantidade),
            vagasRede: Math.round(prest.vagasRede),
            vagasRetorno: Math.round(prest.vagasRetorno),
            vagasReserva: Math.round(prest.vagasReserva),
            medicosTexto: prest.medicosTexto || 'Nenhum médico informado'
          });
        }
        
        categoriasNaoLocalArray.push({
          nome: cat.nome,
          quantidade: Math.round(cat.quantidade),
          prestadores: prestadoresArray
        });
      }
      
      calendario[dia].agendaNaoLocal.categorias = categoriasNaoLocalArray;
    }
    
    Logger.log('Dias processados: ' + Object.keys(calendario).join(', '));
    return calendario;
    
  } catch (error) {
    Logger.log('ERRO: ' + error.toString());
    return {};
  }
}

function getCalendarioMensal(mes, ano) {
  try {
    Logger.log('>>> getCalendarioMensal: INÍCIO - mes=' + mes + ', ano=' + ano);
    
    const primeiroDia = new Date(ano, mes, 1);
    const ultimoDia = new Date(ano, mes + 1, 0);
    const diasNoMes = ultimoDia.getDate();
    const diaSemanaInicio = primeiroDia.getDay();
    
    const calendario = [];
    let semana = [];
    
    // Preenche dias vazios no início
    for (let i = 0; i < diaSemanaInicio; i++) {
      semana.push(null);
    }
    
    // Preenche os dias do mês
    for (let dia = 1; dia <= diasNoMes; dia++) {
      const data = new Date(ano, mes, dia);
      const diaSemana = data.getDay();
      
      const diasMap = ['DOM', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB'];
      const diaSemanaAbrev = diasMap[diaSemana];
      
      semana.push({
        dia: dia,
        diaSemana: diaSemanaAbrev,
        data: Utilities.formatDate(data, Session.getScriptTimeZone(), 'yyyy-MM-dd'),
        dataFormatada: Utilities.formatDate(data, Session.getScriptTimeZone(), 'dd/MM/yyyy')
      });
      
      if (semana.length === 7) {
        calendario.push(semana);
        semana = [];
      }
    }
    
    // Preenche dias vazios no final
    if (semana.length > 0) {
      while (semana.length < 7) {
        semana.push(null);
      }
      calendario.push(semana);
    }
    
    return calendario;
    
  } catch (error) {
    Logger.log('>>> getCalendarioMensal: ERRO - ' + error.toString());
    return [];
  }
}

// ============================================
// FUNÇÕES DE LISTAS
// ============================================

function getPrestadores() {
  try {
    Logger.log('>>> getPrestadores: INÍCIO');
    const dados = lerDadosComPermissao();
    const prestadores = [...new Set(dados.map(d => d.unidade_nome))];
    const resultado = prestadores.filter(p => p).sort();
    Logger.log('>>> getPrestadores: FIM - ' + resultado.length + ' prestadores');
    return resultado;
  } catch (error) {
    Logger.log('>>> getPrestadores: ERRO - ' + error.toString());
    return [];
  }
}

function getCategorias() {
  try {
    Logger.log('>>> getCategorias: INÍCIO');
    const dados = lerDadosComPermissao();
    const categorias = [...new Set(dados.map(d => d.item_nome))];
    const resultado = categorias.filter(c => c).sort();
    Logger.log('>>> getCategorias: FIM - ' + resultado.length + ' categorias');
    return resultado;
  } catch (error) {
    Logger.log('>>> getCategorias: ERRO - ' + error.toString());
    return [];
  }
}

/**
 * Retorna categorias filtradas por prestador
 */
function getCategoriasPorPrestador(prestador) {
  try {
    Logger.log('>>> getCategoriasPorPrestador: INÍCIO - prestador=' + prestador);
    
    if (!prestador || prestador === 'todos') {
      return getCategorias();
    }
    
    const dados = lerDadosComPermissao();
    const categorias = [...new Set(
      dados
        .filter(d => d.unidade_nome === prestador)
        .map(d => d.item_nome)
    )];
    
    const resultado = categorias.filter(c => c).sort();
    Logger.log('>>> getCategoriasPorPrestador: FIM - ' + resultado.length + ' categorias');
    return resultado;
  } catch (error) {
    Logger.log('>>> getCategoriasPorPrestador: ERRO - ' + error.toString());
    return [];
  }
}

/**
 * Retorna grupos (procedimento_nome)
 */
function getGrupos() {
  try {
    Logger.log('>>> getGrupos: INÍCIO');
    const dados = lerDadosComPermissao();
    const grupos = [...new Set(dados.map(d => d.procedimento_nome))];
    const resultado = grupos.filter(g => g).sort();
    Logger.log('>>> getGrupos: FIM - ' + resultado.length + ' grupos');
    return resultado;
  } catch (error) {
    Logger.log('>>> getGrupos: ERRO - ' + error.toString());
    return [];
  }
}

function getMedicos() {
  try {
    Logger.log('>>> getMedicos: INÍCIO');
    const dados = lerDadosComPermissao();
    const medicos = [...new Set(dados.map(d => d['Nome Médico']))];
    const resultado = medicos.filter(m => m).sort();
    Logger.log('>>> getMedicos: FIM - ' + resultado.length + ' médicos');
    return resultado;
  } catch (error) {
    Logger.log('>>> getMedicos: ERRO - ' + error.toString());
    return [];
  }
}

// ============================================
// FUNÇÕES DE FILTRO
// ============================================

function getDadosFiltrados(filtros) {
  try {
    Logger.log('>>> getDadosFiltrados: INÍCIO');
    Logger.log('>>> getDadosFiltrados: Filtros = ' + JSON.stringify(filtros));
    
    const permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return [];
    }
    
    let dados = lerDadosComPermissao();
    Logger.log('>>> getDadosFiltrados: Total de dados = ' + dados.length);
    
    // Detectar escalas compartilhadas
    const escalasMap = {};
    dados.forEach(d => {
      const escalaCodigo = d.escala_codigo;
      if (escalaCodigo) {
        if (!escalasMap[escalaCodigo]) {
          escalasMap[escalaCodigo] = [];
        }
        escalasMap[escalaCodigo].push(d.item_nome);
      }
    });
    
    const escalasCompartilhadas = new Set();
    Object.keys(escalasMap).forEach(codigo => {
      if (escalasMap[codigo].length > 1) {
        escalasCompartilhadas.add(codigo);
      }
    });
    
    // Filtra ativos
    dados = dados.filter(d => {
      const status = d.escala_status;
      if (!status) return false;
      const statusLower = status.toString().toLowerCase().trim();
      return statusLower === 'ativo' || statusLower === 'ativa';
    });
    
    // Aplica filtros
    if (filtros.prestador && filtros.prestador !== 'todos') {
      dados = dados.filter(d => d.unidade_nome === filtros.prestador);
    }
    
    if (filtros.categoria && filtros.categoria !== 'todos') {
      dados = dados.filter(d => d.item_nome === filtros.categoria);
    }
    
    if (filtros.grupo && filtros.grupo !== 'todos') {
      dados = dados.filter(d => d.procedimento_nome === filtros.grupo);
    }
    
    if (filtros.medico && filtros.medico.trim() !== '') {
      const medicoLower = filtros.medico.toLowerCase();
      dados = dados.filter(d => 
        d['Nome Médico'] && 
        d['Nome Médico'].toString().toLowerCase().includes(medicoLower)
      );
    }
    
    if (filtros.diaSemana && filtros.diaSemana !== 'todos') {
      dados = dados.filter(d => d.escala_dia_semana === filtros.diaSemana);
    }
    
    // Filtro de tipo de agenda (respeitando permissão)
    if (filtros.tipoAgenda && filtros.tipoAgenda !== 'todos') {
      dados = dados.filter(d => {
        const local = d.Local;
        if (!local) return false;
        
        const localUpper = local.toString().toUpperCase().trim();
        if (filtros.tipoAgenda === 'local') {
          // Se perfil é parcial, não pode filtrar por local
          if (permissao.perfil === 'parcial') return false;
          return localUpper === 'SIM';
        } else if (filtros.tipoAgenda === 'naoLocal') {
          return localUpper === 'NÃO' || localUpper === 'NAO';
        }
        return false;
      });
    }
    
    // Sanitizar dados
    // Sanitizar dados
    dados = dados.map(d => {
      const escalaCodigo = String(d.escala_codigo || '');
      const isCompartilhada = escalasCompartilhadas.has(escalaCodigo);
      
      // Processar informações de afastamento/bloqueio
      const temAfastamento = (d.tem_afastamento_ativo || '').toString().toUpperCase().trim() === 'SIM';
      
      return {
        unidade_nome: String(d.unidade_nome || ''),
        item_nome: String(d.item_nome || ''),
        procedimento_nome: String(d.procedimento_nome || ''),
        Nome_Medico: String(d['Nome Médico'] || ''),
        escala_horario: formatarHorario(d.escala_horario),
        escala_dia_semana: String(d.escala_dia_semana || ''),
        escala_codigo: escalaCodigo,
        isCompartilhada: isCompartilhada,
        Local: String(d.Local || ''),
        Rede: Number(d.Rede || 0),
        Retorno: Number(d['Retorno '] || d['Retorno'] || 0),
        Reserva: Number(d.Reserva || 0),
        // Campos de bloqueio
        tem_afastamento_ativo: temAfastamento,
        codigo_afastamento: String(d.codigo_afastamento || ''),
        dt_inicio_afastamento: d.dt_inicio_afastamento ? formatarDataBloqueio(d.dt_inicio_afastamento) : '',
        dt_fim_afastamento: d.dt_fim_afastamento ? formatarDataBloqueio(d.dt_fim_afastamento) : '',
        procedimentos_afastamento: String(d.procedimentos_afastamento || ''),
        // NOVOS CAMPOS - VIGÊNCIA DA ESCALA
        vigencia_inicial: d.vigencia_inicial ? formatarDataBloqueio(d.vigencia_inicial) : '',
        vigencia_final: d.vigencia_final ? formatarDataBloqueio(d.vigencia_final) : ''
      };
    });

    Logger.log('>>> getDadosFiltrados: Dados sanitizados - ' + dados.length);
    return dados;
        
  } catch (error) {
    Logger.log('>>> getDadosFiltrados: ERRO - ' + error.toString());
    return [];
  }
}

/**
 * Gera resumo por procedimento respeitando o teto
 * Considera vigência das escalas no mês de referência
 */
function getResumoPorProcedimento(filtros, mesReferencia, anoReferencia) {
  try {
    Logger.log('>>> getResumoPorProcedimento: INÍCIO');
    
    const permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return { erro: true, mensagem: permissao.mensagem };
    }
    
    // Se não informou mês/ano, usa o atual
    if (!mesReferencia || !anoReferencia) {
      var hoje = new Date();
      mesReferencia = hoje.getMonth() + 1;
      anoReferencia = hoje.getFullYear();
    }
    
    let dados = lerDadosComPermissao();
    Logger.log('>>> Total de dados: ' + dados.length);
    
    // Filtra ativos e expirados
    dados = dados.filter(function(d) {
      const status = (d.escala_status || '').toString().toLowerCase().trim();
      return status === 'ativo' || status === 'ativa' || status === 'expirado' || status === 'expirada';
    });
    
    // Aplica filtros (mesma lógica do getDadosFiltrados)
    if (filtros.prestador && filtros.prestador !== 'todos') {
      dados = dados.filter(function(d) { return d.unidade_nome === filtros.prestador; });
    }
    
    if (filtros.categoria && filtros.categoria !== 'todos') {
      dados = dados.filter(function(d) { return d.item_nome === filtros.categoria; });
    }
    
    if (filtros.grupo && filtros.grupo !== 'todos') {
      dados = dados.filter(function(d) { return d.procedimento_nome === filtros.grupo; });
    }
    
    if (filtros.medico && filtros.medico.trim() !== '') {
      const medicoLower = filtros.medico.toLowerCase();
      dados = dados.filter(function(d) {
        return d['Nome Médico'] && d['Nome Médico'].toString().toLowerCase().indexOf(medicoLower) !== -1;
      });
    }
    
    if (filtros.diaSemana && filtros.diaSemana !== 'todos') {
      dados = dados.filter(function(d) { return d.escala_dia_semana === filtros.diaSemana; });
    }
    
    // Filtro de tipo de agenda
    if (filtros.tipoAgenda && filtros.tipoAgenda !== 'todos') {
      dados = dados.filter(function(d) {
        const local = d.Local;
        if (!local) return false;
        const localUpper = local.toString().toUpperCase().trim();
        if (filtros.tipoAgenda === 'local') {
          return localUpper === 'SIM';
        } else if (filtros.tipoAgenda === 'naoLocal') {
          return localUpper === 'NÃO' || localUpper === 'NAO';
        }
        return false;
      });
    }
    
    Logger.log('>>> Dados após filtros: ' + dados.length);
    

    // Detecta escalas compartilhadas
    const escalasItemMap = {};
    dados.forEach(function(d) {
      var escalaCodigo = (d.escala_codigo || '').toString().trim();
      var itemNome = (d.item_nome || '').toString().trim();
      if (escalaCodigo && itemNome) {
        if (!escalasItemMap[escalaCodigo]) {
          escalasItemMap[escalaCodigo] = new Set();
        }
        escalasItemMap[escalaCodigo].add(itemNome);
      }
    });

    var escalasCompartilhadas = {};
    Object.keys(escalasItemMap).forEach(function(codigo) {
      if (escalasItemMap[codigo].size > 1) {
        escalasCompartilhadas[codigo] = true;
      }
    });

    // Agrupa por unidade_codigo + item_nome (procedimento)
    // Rastreia escalas já contabilizadas para não duplicar
    const agrupado = {};
    const escalasContabilizadas = {};
    
    dados.forEach(function(d) {
      const unidadeCodigo = (d.unidade_codigo || '').toString().trim();
      const unidadeNome = (d.unidade_nome || '').toString().trim();
      const itemNome = (d.item_nome || '').toString().trim();
      const escalaCodigo = (d.escala_codigo || '').toString().trim();
      const valorTeto = parseFloat(d.teto_fisico || 0);
      
      if (!unidadeCodigo || !itemNome) return;
      
      // Verifica vigência da escala
      const vigenciaInicial = d.vigencia_inicial;
      const vigenciaFinal = d.vigencia_final;
      const semanasNoMes = calcularSemanasNoMes(vigenciaInicial, vigenciaFinal, mesReferencia, anoReferencia);
      
      // Se a escala não está ativa neste mês, pula
      if (semanasNoMes === 0) {
        return;
      }
      
      // Chave única para agrupamento (prestador + procedimento)
      const chave = unidadeCodigo + '|' + itemNome;
      
      // Inicializa estruturas se não existirem
      if (!escalasContabilizadas[chave]) {
        escalasContabilizadas[chave] = new Set();
      }
      
      if (!agrupado[chave]) {
        agrupado[chave] = {
          unidade_codigo: unidadeCodigo,
          unidade_nome: unidadeNome,
          item_nome: itemNome,
          valor_teto: valorTeto,
          total_escala: 0,
          vagas_rede: 0,
          vagas_locais: 0,
          qtd_escalas: 0,
          tem_compartilhada: false
        };
      }

      // Atualiza o teto se encontrar um valor maior (pega o maior teto encontrado)
      if (valorTeto > agrupado[chave].valor_teto) {
        agrupado[chave].valor_teto = valorTeto;
      }
      
      // Verifica se esta escala já foi contabilizada
      if (escalaCodigo && escalasContabilizadas[chave].has(escalaCodigo)) {
        return;
      }
      
      // Marca escala como contabilizada
      if (escalaCodigo) {
        escalasContabilizadas[chave].add(escalaCodigo);
      }
      
      // Verifica se esta escala é compartilhada
      if (escalaCodigo && escalasCompartilhadas[escalaCodigo]) {
        if (!agrupado[chave]) {
          // será criado abaixo
        }
      }

      // Soma as vagas (usando colunas originais) multiplicadas pelas semanas
      const vagasPrimeiraVez = parseFloat(d['Rede'] || 0);
      const vagasRetorno = parseFloat(d['Retorno'] || 0);
      const vagasReserva = parseFloat(d['Reserva'] || 0);
      const totalVagasSemanal = vagasPrimeiraVez + vagasRetorno + vagasReserva;
      const totalVagasMensal = totalVagasSemanal * semanasNoMes;
      
      const isLocal = (d.Local || '').toString().toUpperCase().trim() === 'SIM';

      agrupado[chave].total_escala += totalVagasMensal;
      if (isLocal) {
        agrupado[chave].vagas_locais += totalVagasMensal;
      } else {
        agrupado[chave].vagas_rede += totalVagasMensal;
      }
      agrupado[chave].qtd_escalas += 1;

      if (escalaCodigo && escalasCompartilhadas[escalaCodigo]) {
        agrupado[chave].tem_compartilhada = true;
      }
    });
    
    Logger.log('>>> Combinações agrupadas: ' + Object.keys(agrupado).length);
    
    // Agora agrupa por procedimento (item_nome), somando os valores corretos de cada prestador
    const resumoPorProcedimento = {};
    
    Object.keys(agrupado).forEach(function(chave) {
      const item = agrupado[chave];
      const itemNome = item.item_nome;
      
      // Calcula valor correto (mínimo entre escala e teto)
      // Se teto é 0 ou não existe, usa o valor da escala
      let valorCorreto;
      if (item.valor_teto > 0) {
        valorCorreto = Math.min(item.total_escala, item.valor_teto);
      } else {
        valorCorreto = Math.min(item.total_escala, item.valor_teto);
      }
      
      if (!resumoPorProcedimento[itemNome]) {
        resumoPorProcedimento[itemNome] = {
          item_nome: itemNome,
          total_geral: 0,
          detalhes: []
        };
      }
      
      resumoPorProcedimento[itemNome].total_geral += valorCorreto;
      resumoPorProcedimento[itemNome].detalhes.push({
        unidade_codigo: item.unidade_codigo,
        unidade_nome: item.unidade_nome,
        total_escala: Math.round(item.total_escala),
        vagas_rede: Math.round(item.vagas_rede),
        vagas_locais: Math.round(item.vagas_locais),
        valor_teto: Math.round(item.valor_teto),
        valor_correto: Math.round(valorCorreto),
        qtd_escalas: item.qtd_escalas,
        tem_compartilhada: item.tem_compartilhada
      });
    });
    
    // Converte para array e ordena por nome do procedimento
    const resultado = Object.values(resumoPorProcedimento).map(function(proc) {
      proc.total_geral = Math.round(proc.total_geral);
      // Ordena detalhes por nome do prestador
      proc.detalhes.sort(function(a, b) {
        return a.unidade_nome.localeCompare(b.unidade_nome);
      });
      return proc;
    });
    
    resultado.sort(function(a, b) {
      return a.item_nome.localeCompare(b.item_nome);
    });
    
    Logger.log('>>> getResumoPorProcedimento: FIM - ' + resultado.length + ' procedimentos');
    
    return {
      erro: false,
      resumo: resultado,
      mes_referencia: mesReferencia,
      ano_referencia: anoReferencia,
      total_procedimentos: resultado.length,
      total_geral: resultado.reduce(function(sum, p) { return sum + p.total_geral; }, 0)
    };
    
  } catch (error) {
    Logger.log('>>> ERRO em getResumoPorProcedimento: ' + error.toString());
    return { erro: true, mensagem: error.toString() };
  }
}

/**
 * Exporta o resumo por procedimento para Excel
 */
function exportarResumoProcedimentoExcel(filtros, mesReferencia, anoReferencia) {
  try {
    // Obtém os dados do resumo
    const dadosResumo = getResumoPorProcedimento(filtros, mesReferencia, anoReferencia);
    
    if (dadosResumo.erro) {
      return { sucesso: false, mensagem: dadosResumo.mensagem };
    }
    
    if (!dadosResumo.resumo || dadosResumo.resumo.length === 0) {
      return { sucesso: false, mensagem: 'Nenhum dado para exportar.' };
    }
    
    // Cria uma nova planilha
    const mesesNomes = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    const nomeMes = mesesNomes[mesReferencia - 1];
    const nomeArquivo = 'Resumo_Procedimentos_' + nomeMes + '_' + anoReferencia + '_' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmm');
    
    const ss = SpreadsheetApp.create(nomeArquivo);
    
    // ========== ABA 1: RESUMO CONSOLIDADO ==========
    const sheetResumo = ss.getActiveSheet();
    sheetResumo.setName('Resumo Consolidado');
    
    // Cabeçalho do relatório
    sheetResumo.getRange('A1').setValue('RESUMO POR PROCEDIMENTO - ' + nomeMes.toUpperCase() + ' ' + anoReferencia);
    sheetResumo.getRange('A1').setFontSize(14).setFontWeight('bold').setBackground('#8B5CF6').setFontColor('white');
    sheetResumo.getRange('A1:B1').merge();
    
    sheetResumo.getRange('A2').setValue('Gerado em: ' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'dd/MM/yyyy HH:mm'));
    sheetResumo.getRange('A3').setValue('Total de Procedimentos: ' + dadosResumo.total_procedimentos);
    sheetResumo.getRange('A4').setValue('Total Geral de Vagas: ' + dadosResumo.total_geral.toLocaleString('pt-BR'));
    
    // Cabeçalhos da tabela
    const headersResumo = ['Procedimento', 'Total de Vagas'];
    sheetResumo.getRange(6, 1, 1, headersResumo.length).setValues([headersResumo]);
    sheetResumo.getRange(6, 1, 1, headersResumo.length).setFontWeight('bold').setBackground('#A78BFA').setFontColor('white');
    
    // Dados
    const linhasResumo = dadosResumo.resumo.map(function(proc) {
      return [proc.item_nome, proc.total_geral];
    });
    
    if (linhasResumo.length > 0) {
      sheetResumo.getRange(7, 1, linhasResumo.length, headersResumo.length).setValues(linhasResumo);
      sheetResumo.getRange(7, 2, linhasResumo.length, 1).setNumberFormat('#,##0');
    }
    
    // Linha de total
    const linhaTotal = 7 + linhasResumo.length;
    sheetResumo.getRange(linhaTotal, 1).setValue('TOTAL GERAL');
    sheetResumo.getRange(linhaTotal, 2).setValue(dadosResumo.total_geral);
    sheetResumo.getRange(linhaTotal, 1, 1, 2).setFontWeight('bold').setBackground('#E5E7EB');
    sheetResumo.getRange(linhaTotal, 2).setNumberFormat('#,##0');
    
    // Auto-ajusta colunas
    sheetResumo.autoResizeColumn(1);
    sheetResumo.autoResizeColumn(2);
    
    // ========== ABA 2: DETALHAMENTO POR PRESTADOR ==========
    const sheetDetalhe = ss.insertSheet('Detalhamento por Prestador');
    
    // Cabeçalho
    sheetDetalhe.getRange('A1').setValue('DETALHAMENTO POR PRESTADOR - ' + nomeMes.toUpperCase() + ' ' + anoReferencia);
    sheetDetalhe.getRange('A1').setFontSize(14).setFontWeight('bold').setBackground('#8B5CF6').setFontColor('white');
    sheetDetalhe.getRange('A1:F1').merge();
    
    // Cabeçalhos da tabela
    const headersDetalhe = ['Procedimento', 'Prestador', 'CNES', 'Vagas Escala', 'Vagas Rede', 'Vagas Locais', 'Teto', 'Valor Considerado', 'Observação'];
    sheetDetalhe.getRange(3, 1, 1, headersDetalhe.length).setValues([headersDetalhe]);
    sheetDetalhe.getRange(3, 1, 1, headersDetalhe.length).setFontWeight('bold').setBackground('#A78BFA').setFontColor('white');
    
    // Dados detalhados
    const linhasDetalhe = [];
    dadosResumo.resumo.forEach(function(proc) {
      proc.detalhes.forEach(function(det) {
        var observacao = det.tem_compartilhada ? 'Escala compartilhada - valor representa capacidade máxima' : '';
        linhasDetalhe.push([
          proc.item_nome,
          det.unidade_nome,
          det.unidade_codigo,
          det.total_escala,
          det.vagas_rede,
          det.vagas_locais,
          det.valor_teto,
          det.valor_correto,
          observacao
        ]);
      });
    });
    
    if (linhasDetalhe.length > 0) {
      sheetDetalhe.getRange(4, 1, linhasDetalhe.length, headersDetalhe.length).setValues(linhasDetalhe);
      sheetDetalhe.getRange(4, 4, linhasDetalhe.length, 1).setNumberFormat('#,##0');
      sheetDetalhe.getRange(4, 6, linhasDetalhe.length, 1).setNumberFormat('#,##0');
    }
    
    // Auto-ajusta colunas
    for (var i = 1; i <= headersDetalhe.length; i++) {
      sheetDetalhe.autoResizeColumn(i);
    }
    
    // Adiciona filtros
    if (linhasDetalhe.length > 0) {
      sheetDetalhe.getRange(3, 1, linhasDetalhe.length + 1, headersDetalhe.length).createFilter();
    }
    
    // Formata células onde escala > teto (destacar em vermelho)
    for (var row = 4; row < 4 + linhasDetalhe.length; row++) {
      var escala = sheetDetalhe.getRange(row, 4).getValue();
      var teto = sheetDetalhe.getRange(row, 5).getValue();
      if (typeof teto === 'number' && escala > teto) {  // ← JÁ ESTÁ CORRETO
        sheetDetalhe.getRange(row, 4).setBackground('#FEE2E2'); // Vermelho claro
        sheetDetalhe.getRange(row, 6).setBackground('#D1FAE5'); // Verde claro (valor corrigido)
      }
    }
    
    Logger.log('>>> Resumo exportado com sucesso: ' + nomeArquivo);
    
    return {
      sucesso: true,
      url: ss.getUrl(),
      mensagem: 'Relatório gerado com sucesso!'
    };
    
  } catch (error) {
    Logger.log('>>> ERRO ao exportar resumo: ' + error.toString());
    return {
      sucesso: false,
      mensagem: error.toString()
    };
  }
}

// ============================================
// FUNÇÕES DE TESTE
// ============================================

function testarConexao() {
  try {
    const permissao = verificarPermissao();
    Logger.log('Permissão: ' + JSON.stringify(permissao));
    
    const dados = lerDadosComPermissao();
    Logger.log(`Total de registros: ${dados.length}`);
    
    return {
      sucesso: true,
      permissao: permissao,
      mensagem: `Conexão OK! ${dados.length} registros encontrados.`
    };
  } catch (error) {
    Logger.log('Erro no teste: ' + error.toString());
    return {
      sucesso: false,
      mensagem: error.toString()
    };
  }
}

/**
 * Função auxiliar para criar a aba de permissões
 * Execute esta função uma vez para criar a estrutura
 */
function criarAbaPermissoes() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName(CONFIG.PERMISSOES_SHEET);
  
  if (!sheet) {
    sheet = ss.insertSheet(CONFIG.PERMISSOES_SHEET);
    
    // Cabeçalhos
    sheet.getRange('A1:C1').setValues([['email', 'perfil', 'nome']]);
    sheet.getRange('A1:C1').setFontWeight('bold');
    sheet.getRange('A1:C1').setBackground('#4285f4');
    sheet.getRange('A1:C1').setFontColor('white');
    
    // Exemplo de dados
    sheet.getRange('A2:C2').setValues([['admin@exemplo.com', 'total', 'Administrador']]);
    sheet.getRange('A3:C3').setValues([['usuario@exemplo.com', 'parcial', 'Usuário Padrão']]);
    
    // Ajusta largura das colunas
    sheet.setColumnWidth(1, 250);
    sheet.setColumnWidth(2, 100);
    sheet.setColumnWidth(3, 200);
    
    // Validação de dados para coluna perfil
    const regra = SpreadsheetApp.newDataValidation()
      .requireValueInList(['total', 'parcial'], true)
      .setAllowInvalid(false)
      .build();
    sheet.getRange('B2:B100').setDataValidation(regra);
    
    Logger.log('>>> Aba de permissões criada com sucesso!');
    return 'Aba "Permissoes" criada com sucesso!';
  } else {
    Logger.log('>>> Aba de permissões já existe.');
    return 'Aba "Permissoes" já existe.';
  }
}


// ============================================
// FUNÇÕES DE EXPORTAÇÃO DE RELATÓRIOS
// ============================================

/**
 * Exporta relatório para Excel (Google Sheets)
 */
function exportarRelatorioExcel(dados) {
  try {
    if (!dados || dados.length === 0) {
      return { sucesso: false, mensagem: 'Nenhum dado para exportar.' };
    }
    
    // Cria uma nova planilha
    var nomeArquivo = 'Relatorio_Escalas_' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmm');
    var ss = SpreadsheetApp.create(nomeArquivo);
    var sheet = ss.getActiveSheet();
    sheet.setName('Escalas');
    
    // Cabeçalhos
    var headers = [
      'Dia da Semana',
      'Categoria',
      'Prestador',
      'Médico',
      'Horário',
      'Código Escala',
      'Grupo/Procedimento',
      'Tipo Agenda',
      'Vagas Rede',
      'Vagas Retorno',
      'Vagas Reserva',
      'Total Vagas',
      'Bloqueio Ativo',
      'Início Bloqueio',
      'Fim Bloqueio',
      'Código Bloqueio',
      'Vigência Inicial',    // NOVO
      'Vigência Final'       // NOVO
    ];
    
    // Estiliza cabeçalhos
    var headerRange = sheet.getRange(1, 1, 1, headers.length);
    headerRange.setValues([headers]);
    headerRange.setFontWeight('bold');
    headerRange.setBackground('#8B5CF6');
    headerRange.setFontColor('white');
    headerRange.setHorizontalAlignment('center');
    
    // Dados
    var linhas = [];
    dados.forEach(function(r) {
      var rede = parseFloat(r.Rede || 0);
      var retorno = parseFloat(r.Retorno || 0);
      var reserva = parseFloat(r.Reserva || 0);
      var total = rede + retorno + reserva;
      var tipoAgenda = (r.Local || '').toString().toUpperCase().trim() === 'SIM' ? 'Local' : 'Não Local';
      
      // Informações de bloqueio
      var bloqueioAtivo = r.tem_afastamento_ativo ? 'SIM' : 'NÃO';
      var inicioBloqueio = r.dt_inicio_afastamento || '';
      var fimBloqueio = r.dt_fim_afastamento || '';
      var codigoBloqueio = r.codigo_afastamento || '';
      
      linhas.push([
        r.escala_dia_semana || '',
        r.item_nome || '',
        r.unidade_nome || '',
        r.Nome_Medico || '',
        r.escala_horario || '',
        r.escala_codigo || '',
        r.procedimento_nome || '',
        tipoAgenda,
        rede,
        retorno,
        reserva,
        total,
        bloqueioAtivo,
        inicioBloqueio,
        fimBloqueio,
        codigoBloqueio,
        r.vigencia_inicial || '',    // NOVO
        r.vigencia_final || ''       // NOVO
      ]);
    });
    
    if (linhas.length > 0) {
      sheet.getRange(2, 1, linhas.length, headers.length).setValues(linhas);
    }
    
    // Auto-ajusta colunas
    for (var i = 1; i <= headers.length; i++) {
      sheet.autoResizeColumn(i);
    }
    
    // Adiciona filtros
    sheet.getRange(1, 1, linhas.length + 1, headers.length).createFilter();
    
    // Formata colunas numéricas
    sheet.getRange(2, 9, linhas.length, 4).setNumberFormat('#,##0');
    
    // Adiciona aba de resumo
    var resumoSheet = ss.insertSheet('Resumo');
    var totalVagas = 0, totalRede = 0, totalRetorno = 0, totalReserva = 0;
    linhas.forEach(function(l) {
      totalRede += l[8];
      totalRetorno += l[9];
      totalReserva += l[10];
      totalVagas += l[11];
    });
    
    resumoSheet.getRange('A1:B1').setValues([['RESUMO DO RELATÓRIO', '']]);
    resumoSheet.getRange('A1').setFontSize(14).setFontWeight('bold');
    resumoSheet.getRange('A3:B7').setValues([
      ['Total de Registros', linhas.length],
      ['Total de Vagas', totalVagas],
      ['Vagas Rede', totalRede],
      ['Vagas Retorno', totalRetorno],
      ['Vagas Reserva', totalReserva]
    ]);
    resumoSheet.getRange('A3:A7').setFontWeight('bold');
    resumoSheet.autoResizeColumn(1);
    resumoSheet.autoResizeColumn(2);
    
    // Retorna URL do arquivo
    return {
      sucesso: true,
      url: ss.getUrl(),
      mensagem: 'Relatório gerado com sucesso!'
    };
    
  } catch (error) {
    Logger.log('Erro ao exportar Excel: ' + error.toString());
    return {
      sucesso: false,
      mensagem: error.toString()
    };
  }
}

/**
 * Retorna a data da última extração dos dados
 */
function getUltimaAtualizacao() {
  try {
    const dados = lerDadosPlanilha();
    
    if (!dados || dados.length === 0) {
      return { sucesso: false, data: null };
    }
    
    let ultimaData = null;
    
    dados.forEach(function(d) {
      const dataExtracao = d.data_extracao;
      if (dataExtracao) {
        let dataObj;
        
        // Se for string no formato "2026-01-19 09:36:03"
        if (typeof dataExtracao === 'string') {
          // Pega apenas a parte da data (antes do espaço)
          const partesDateTime = dataExtracao.split(' ');
          const partesData = partesDateTime[0].split('-');
          if (partesData.length === 3) {
            dataObj = new Date(partesData[0], partesData[1] - 1, partesData[2]);
          }
        } 
        // Se for objeto Date
        else if (dataExtracao instanceof Date) {
          dataObj = dataExtracao;
        }
        
        if (dataObj && !isNaN(dataObj.getTime())) {
          if (!ultimaData || dataObj > ultimaData) {
            ultimaData = dataObj;
          }
        }
      }
    });
    
    if (ultimaData) {
      // Formata para dd/mm/yyyy
      const dia = String(ultimaData.getDate()).padStart(2, '0');
      const mes = String(ultimaData.getMonth() + 1).padStart(2, '0');
      const ano = ultimaData.getFullYear();
      
      return {
        sucesso: true,
        data: dia + '/' + mes + '/' + ano
      };
    }
    
    return { sucesso: false, data: null };
    
  } catch (error) {
    Logger.log('Erro ao obter última atualização: ' + error.toString());
    return { sucesso: false, data: null };
  }
}

/**
 * Retorna dados de distribuição de escalas por prestador
 * (% Local vs % Não Local)
 */
function getDistribuicaoEscalas() {
  try {
    Logger.log('>>> getDistribuicaoEscalas: INÍCIO');
    
    const permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return { erro: true, mensagem: permissao.mensagem };
    }
    
    // Usa a função que já respeita permissões
    const dados = lerDadosComPermissao();
    
    if (!dados || dados.length === 0) {
      return [];
    }
    
    // Filtra apenas ativos
    const ativos = dados.filter(function(d) {
      if (!d.escala_status) return false;
      const status = d.escala_status.toString().toLowerCase().trim();
      return status === 'ativo' || status === 'ativa';
    });
    
    // Agrupa por prestador
    const prestadoresMap = {};
    
    ativos.forEach(function(d) {
      const prestador = d.unidade_nome;
      if (!prestador) return;
      
      if (!prestadoresMap[prestador]) {
        prestadoresMap[prestador] = {
          nome: prestador,
          local: 0,
          naoLocal: 0,
          total: 0
        };
      }
      
      const rede = parseFloat(d['Rede'] || 0);
      const retorno = parseFloat(d['Retorno '] || d['Retorno'] || 0);
      const reserva = parseFloat(d['Reserva'] || 0);
      const totalVagas = rede + retorno + reserva;
      
      // Verifica se é local ou não
      const local = d.Local;
      if (local) {
        const localUpper = local.toString().toUpperCase().trim();
        if (localUpper === 'SIM') {
          prestadoresMap[prestador].local += totalVagas;
        } else if (localUpper === 'NÃO' || localUpper === 'NAO') {
          prestadoresMap[prestador].naoLocal += totalVagas;
        }
      } else {
        // Se não tem informação, considera como não local
        prestadoresMap[prestador].naoLocal += totalVagas;
      }
      
      prestadoresMap[prestador].total += totalVagas;
    });
    
    // Converte para array e ordena por nome
    const resultado = Object.values(prestadoresMap)
      .filter(function(p) { return p.total > 0; })
      .sort(function(a, b) { return a.nome.localeCompare(b.nome); });
    
    // Arredonda valores
    resultado.forEach(function(p) {
      p.local = Math.round(p.local);
      p.naoLocal = Math.round(p.naoLocal);
      p.total = Math.round(p.total);
    });
    
    Logger.log('>>> getDistribuicaoEscalas: FIM - ' + resultado.length + ' prestadores');
    return resultado;
    
  } catch (error) {
    Logger.log('>>> getDistribuicaoEscalas: ERRO - ' + error.toString());
    return { erro: true, mensagem: error.toString() };
  }
}

// ============================================
// DISTRIBUIÇÃO DE ESCALAS V2 - COM PERÍODO E VIGÊNCIA
// ============================================

/**
 * Retorna dados de distribuição de escalas por prestador
 * VERSÃO V2: Considera vigência, escalas expiradas, compartilhadas E BLOQUEIOS
 * @param {number} mesReferencia - Mês de referência (1-12)
 * @param {number} anoReferencia - Ano de referência
 */
function getDistribuicaoEscalasV2(mesReferencia, anoReferencia) {
  try {
    Logger.log('>>> getDistribuicaoEscalasV2: INÍCIO - Mês: ' + mesReferencia + '/' + anoReferencia);
    
    var permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return { erro: true, mensagem: permissao.mensagem };
    }
    
    // Se não informou mês/ano, usa o atual
    if (!mesReferencia || !anoReferencia) {
      var hoje = new Date();
      mesReferencia = hoje.getMonth() + 1;
      anoReferencia = hoje.getFullYear();
    }
    
    // Lê dados COM permissão (respeita perfil parcial)
    var dados = lerDadosPlanilha();
    
    // Aplica filtro de permissão se necessário
    if (permissao.perfil === 'parcial') {
      dados = dados.filter(function(d) {
        var local = d.Local;
        if (!local) return true;
        var localUpper = local.toString().toUpperCase().trim();
        return localUpper === 'NÃO' || localUpper === 'NAO';
      });
    }
    
    if (!dados || dados.length === 0) {
      return { erro: false, distribuicao: [], resumo: { totalPrestadores: 0, totalVagas: 0, totalLocal: 0, totalNaoLocal: 0, totalBloqueado: 0, totalDisponivel: 0 }, mes_referencia: mesReferencia, ano_referencia: anoReferencia };
    }
    
    // 1. Filtra apenas ativos E expirados
    var dadosFiltrados = dados.filter(function(d) {
      var status = (d.escala_status || '').toString().toLowerCase().trim();
      return status === 'ativo' || status === 'ativa' || status === 'expirado' || status === 'expirada';
    });
    
    Logger.log('>>> Dados ativos/expirados: ' + dadosFiltrados.length);
    
    // 2. Identifica escalas compartilhadas
    var escalasProcedimentos = {};
    
    dadosFiltrados.forEach(function(d) {
      var escalaCodigo = (d.escala_codigo || '').toString().trim();
      var itemNome = (d.item_nome || '').toString().trim();
      
      if (!escalaCodigo) return;
      
      if (!escalasProcedimentos[escalaCodigo]) {
        escalasProcedimentos[escalaCodigo] = new Set();
      }
      escalasProcedimentos[escalaCodigo].add(itemNome);
    });
    
    var escalasQtdProcedimentos = {};
    Object.keys(escalasProcedimentos).forEach(function(escala) {
      escalasQtdProcedimentos[escala] = escalasProcedimentos[escala].size;
    });
    
    // 3. Agrupa por prestador, controlando escalas já contabilizadas
    var prestadoresMap = {};
    var escalasContabilizadas = {};
    
    dadosFiltrados.forEach(function(d) {
      var prestador = (d.unidade_nome || '').toString().trim();
      var escalaCodigo = (d.escala_codigo || '').toString().trim();
      
      if (!prestador) return;
      
      // Verifica vigência da escala no mês de referência
      var vigenciaInicial = d.vigencia_inicial;
      var vigenciaFinal = d.vigencia_final;
      var semanasNoMes = calcularSemanasNoMes(vigenciaInicial, vigenciaFinal, mesReferencia, anoReferencia);
      
      if (semanasNoMes === 0) {
        return;
      }
      
      // Inicializa estruturas
      if (!escalasContabilizadas[prestador]) {
        escalasContabilizadas[prestador] = new Set();
      }
      
      if (!prestadoresMap[prestador]) {
        prestadoresMap[prestador] = {
          nome: prestador,
          local: 0,
          naoLocal: 0,
          total: 0,
          bloqueado: 0,
          bloqueadoLocal: 0,
          bloqueadoNaoLocal: 0,
          qtdEscalas: 0,
          qtdEscalasCompartilhadas: 0,
          qtdEscalasBloqueadas: 0
        };
      }
      
      // Verifica se esta escala já foi contabilizada para este prestador
      if (escalaCodigo && escalasContabilizadas[prestador].has(escalaCodigo)) {
        return;
      }
      
      // Marca escala como contabilizada
      if (escalaCodigo) {
        escalasContabilizadas[prestador].add(escalaCodigo);
      }
      
      // Calcula vagas semanais
      var rede = parseFloat(d['Rede'] || 0);
      var retorno = parseFloat(d['Retorno '] || d['Retorno'] || 0);
      var reserva = parseFloat(d['Reserva'] || 0);
      var totalSemanal = rede + retorno + reserva;
      
      // Calcula total mensal baseado nas semanas ativas
      var totalMensal = totalSemanal * semanasNoMes;
      
      // ====== CÁLCULO DE BLOQUEIO ======
      var temBloqueio = (d.tem_afastamento_ativo || '').toString().toUpperCase().trim() === 'SIM';
      var semanasComBloqueio = 0;
      
      if (temBloqueio) {
        var dtInicio = d.dt_inicio_afastamento;
        var dtFim = d.dt_fim_afastamento;
        
        if (dtInicio && dtFim) {
          var dataInicioBloq = converterParaData(dtInicio);
          var dataFimBloq = converterParaData(dtFim);
          
          if (dataInicioBloq && dataFimBloq && !isNaN(dataInicioBloq.getTime()) && !isNaN(dataFimBloq.getTime())) {
            // Limites do mês de referência
            var primeiroDiaMes = new Date(anoReferencia, mesReferencia - 1, 1);
            var ultimoDiaMes = new Date(anoReferencia, mesReferencia, 0);
            
            // Ajusta datas do bloqueio para dentro do mês
            var inicioBloqueioEfetivo = dataInicioBloq > primeiroDiaMes ? dataInicioBloq : primeiroDiaMes;
            var fimBloqueioEfetivo = dataFimBloq < ultimoDiaMes ? dataFimBloq : ultimoDiaMes;
            
            if (inicioBloqueioEfetivo <= fimBloqueioEfetivo) {
              var diffDias = Math.ceil((fimBloqueioEfetivo - inicioBloqueioEfetivo) / (1000 * 60 * 60 * 24)) + 1;
              semanasComBloqueio = Math.min(semanasNoMes, Math.ceil(diffDias / 7));
            }
          }
        } else {
          // Sem datas específicas → considera bloqueio total nas semanas ativas
          semanasComBloqueio = semanasNoMes;
        }
      }
      
      var totalBloqueadoMensal = totalSemanal * semanasComBloqueio;
      // ====== FIM CÁLCULO DE BLOQUEIO ======
      
      // Verifica se é local ou não
      var local = d.Local;
      var isLocal = false;
      if (local) {
        var localUpper = local.toString().toUpperCase().trim();
        isLocal = (localUpper === 'SIM');
      }
      
      // Verifica se é escala compartilhada
      var qtdProcedimentosNaEscala = escalasQtdProcedimentos[escalaCodigo] || 1;
      var isCompartilhada = qtdProcedimentosNaEscala > 1;
      
      // Soma vagas brutas (antes do desconto)
      if (isLocal) {
        prestadoresMap[prestador].local += totalMensal;
        prestadoresMap[prestador].bloqueadoLocal += totalBloqueadoMensal;
      } else {
        prestadoresMap[prestador].naoLocal += totalMensal;
        prestadoresMap[prestador].bloqueadoNaoLocal += totalBloqueadoMensal;
      }
      prestadoresMap[prestador].total += totalMensal;
      prestadoresMap[prestador].bloqueado += totalBloqueadoMensal;
      prestadoresMap[prestador].qtdEscalas += 1;
      
      if (isCompartilhada) {
        prestadoresMap[prestador].qtdEscalasCompartilhadas += 1;
      }
      
      if (temBloqueio && semanasComBloqueio > 0) {
        prestadoresMap[prestador].qtdEscalasBloqueadas += 1;
      }
    });
    
    // 4. Converte para array, arredonda e ordena
    var resultado = Object.values(prestadoresMap)
      .filter(function(p) { return p.total > 0; })
      .map(function(p) {
        var localDisp = p.local - p.bloqueadoLocal;
        var naoLocalDisp = p.naoLocal - p.bloqueadoNaoLocal;
        var totalDisp = p.total - p.bloqueado;
        
        return {
          nome: p.nome,
          // Valores BRUTOS (antes do desconto)
          localBruto: Math.round(p.local),
          naoLocalBruto: Math.round(p.naoLocal),
          totalBruto: Math.round(p.total),
          // Valores BLOQUEADOS
          bloqueado: Math.round(p.bloqueado),
          bloqueadoLocal: Math.round(p.bloqueadoLocal),
          bloqueadoNaoLocal: Math.round(p.bloqueadoNaoLocal),
          // Valores DISPONÍVEIS (bruto - bloqueado)
          local: Math.round(localDisp),
          naoLocal: Math.round(naoLocalDisp),
          total: Math.round(totalDisp),
          // Contadores
          qtdEscalas: p.qtdEscalas,
          qtdEscalasCompartilhadas: p.qtdEscalasCompartilhadas,
          qtdEscalasBloqueadas: p.qtdEscalasBloqueadas
        };
      })
      .sort(function(a, b) { return a.nome.localeCompare(b.nome); });
    
    // 5. Calcula resumo geral
    var resumo = {
      totalPrestadores: resultado.length,
      totalVagas: resultado.reduce(function(sum, p) { return sum + p.totalBruto; }, 0),
      totalLocal: resultado.reduce(function(sum, p) { return sum + p.localBruto; }, 0),
      totalNaoLocal: resultado.reduce(function(sum, p) { return sum + p.naoLocalBruto; }, 0),
      totalBloqueado: resultado.reduce(function(sum, p) { return sum + p.bloqueado; }, 0),
      totalDisponivel: resultado.reduce(function(sum, p) { return sum + p.total; }, 0),
      totalEscalas: resultado.reduce(function(sum, p) { return sum + p.qtdEscalas; }, 0),
      totalEscalasBloqueadas: resultado.reduce(function(sum, p) { return sum + p.qtdEscalasBloqueadas; }, 0)
    };
    
    Logger.log('>>> getDistribuicaoEscalasV2: FIM - ' + resultado.length + ' prestadores, Bruto: ' + resumo.totalVagas + ', Bloqueado: ' + resumo.totalBloqueado + ', Disponível: ' + resumo.totalDisponivel);
    
    return {
      erro: false,
      distribuicao: resultado,
      resumo: resumo,
      mes_referencia: mesReferencia,
      ano_referencia: anoReferencia
    };
    
  } catch (error) {
    Logger.log('>>> ERRO em getDistribuicaoEscalasV2: ' + error.toString());
    return { erro: true, mensagem: error.toString() };
  }
}

/**
 * Exporta relatório de distribuição de escalas para Excel
 * @param {number} mesReferencia - Mês (1-12)
 * @param {number} anoReferencia - Ano
 * @param {string} filtroPrestador - Filtro opcional
 * @param {string} ordenacao - Tipo de ordenação
 */
function exportarDistribuicaoExcel(mesReferencia, anoReferencia, filtroPrestador, ordenacao) {
  try {
    Logger.log('>>> exportarDistribuicaoExcel: INÍCIO');
    
    // Obtém os dados
    var dados = getDistribuicaoEscalasV2(mesReferencia, anoReferencia);
    
    if (dados.erro) {
      return { sucesso: false, mensagem: dados.mensagem };
    }
    
    if (!dados.distribuicao || dados.distribuicao.length === 0) {
      return { sucesso: false, mensagem: 'Nenhum dado para exportar.' };
    }
    
    // Aplica filtro de prestador se informado
    var prestadores = dados.distribuicao;
    if (filtroPrestador && filtroPrestador.trim() !== '') {
      var filtroLower = filtroPrestador.toLowerCase().trim();
      prestadores = prestadores.filter(function(p) {
        return p.nome.toLowerCase().indexOf(filtroLower) !== -1;
      });
    }
    
    // Aplica ordenação
    if (ordenacao) {
      prestadores = ordenarPrestadoresDistribuicao(prestadores, ordenacao);
    }
    
    if (prestadores.length === 0) {
      return { sucesso: false, mensagem: 'Nenhum prestador encontrado com o filtro informado.' };
    }
    
    // Cria planilha
    var mesesNomes = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    var nomeMes = mesesNomes[mesReferencia - 1];
    var nomeArquivo = 'Distribuicao_Escalas_' + nomeMes + '_' + anoReferencia + '_' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmm');
    
    var ss = SpreadsheetApp.create(nomeArquivo);
    var sheet = ss.getActiveSheet();
    sheet.setName('Distribuição por Prestador');
    
    // ===== CABEÇALHO DO RELATÓRIO =====
    sheet.getRange('A1').setValue('DISTRIBUIÇÃO DE ESCALAS POR PRESTADOR - ' + nomeMes.toUpperCase() + ' ' + anoReferencia);
    sheet.getRange('A1').setFontSize(14).setFontWeight('bold').setBackground('#8B5CF6').setFontColor('white');
    sheet.getRange('A1:H1').merge();
    
    sheet.getRange('A2').setValue('Gerado em: ' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'dd/MM/yyyy HH:mm'));
    sheet.getRange('A3').setValue('Total de Prestadores: ' + prestadores.length);
    sheet.getRange('A4').setValue('Total Geral de Vagas: ' + dados.resumo.totalVagas.toLocaleString('pt-BR'));
    
    // ===== CABEÇALHOS DA TABELA =====
    var headers = ['Prestador', 'Vagas Locais (Disp.)', 'Vagas Não Locais (Disp.)', 'Total Disponível', 'Total Bruto', 'Bloqueado', '% Local', '% Não Local', 'Qtd Escalas', 'Esc. Compartilhadas', 'Esc. Bloqueadas'];
    sheet.getRange(6, 1, 1, headers.length).setValues([headers]);
    sheet.getRange(6, 1, 1, headers.length).setFontWeight('bold').setBackground('#A78BFA').setFontColor('white').setHorizontalAlignment('center');
    
    // ===== DADOS =====
    var linhas = prestadores.map(function(p) {
      var percentLocal = p.total > 0 ? ((p.local / p.total) * 100).toFixed(1) : '0.0';
      var percentNaoLocal = p.total > 0 ? ((p.naoLocal / p.total) * 100).toFixed(1) : '0.0';
      
      return [
        p.nome,
        p.local,
        p.naoLocal,
        p.total,
        p.totalBruto,
        p.bloqueado,
        parseFloat(percentLocal) / 100,
        parseFloat(percentNaoLocal) / 100,
        p.qtdEscalas,
        p.qtdEscalasCompartilhadas,
        p.qtdEscalasBloqueadas
      ];
    });
    
    if (linhas.length > 0) {
      sheet.getRange(7, 1, linhas.length, headers.length).setValues(linhas);
      
      // Formata colunas numéricas
      sheet.getRange(7, 2, linhas.length, 5).setNumberFormat('#,##0');
      sheet.getRange(7, 7, linhas.length, 2).setNumberFormat('0.0%');
      sheet.getRange(7, 9, linhas.length, 3).setNumberFormat('#,##0');
    }
    
    // ===== LINHA DE TOTAIS =====
    var linhaTotal = 7 + linhas.length;
    var totalLocal = prestadores.reduce(function(sum, p) { return sum + p.local; }, 0);
    var totalNaoLocal = prestadores.reduce(function(sum, p) { return sum + p.naoLocal; }, 0);
    var totalDisponivel = prestadores.reduce(function(sum, p) { return sum + p.total; }, 0);
    var totalBruto = prestadores.reduce(function(sum, p) { return sum + p.totalBruto; }, 0);
    var totalBloqueado = prestadores.reduce(function(sum, p) { return sum + p.bloqueado; }, 0);
    var totalEscalas = prestadores.reduce(function(sum, p) { return sum + p.qtdEscalas; }, 0);
    var totalCompartilhadas = prestadores.reduce(function(sum, p) { return sum + p.qtdEscalasCompartilhadas; }, 0);
    var totalEscBloqueadas = prestadores.reduce(function(sum, p) { return sum + p.qtdEscalasBloqueadas; }, 0);
    var pctLocalGeral = totalDisponivel > 0 ? (totalLocal / totalDisponivel) : 0;
    var pctNaoLocalGeral = totalDisponivel > 0 ? (totalNaoLocal / totalDisponivel) : 0;
    
    sheet.getRange(linhaTotal, 1, 1, headers.length).setValues([['TOTAL GERAL', totalLocal, totalNaoLocal, totalDisponivel, totalBruto, totalBloqueado, pctLocalGeral, pctNaoLocalGeral, totalEscalas, totalCompartilhadas, totalEscBloqueadas]]);
    sheet.getRange(linhaTotal, 1, 1, headers.length).setFontWeight('bold').setBackground('#E5E7EB');
    sheet.getRange(linhaTotal, 2, 1, 5).setNumberFormat('#,##0');
    sheet.getRange(linhaTotal, 7, 1, 2).setNumberFormat('0.0%');
    sheet.getRange(linhaTotal, 9, 1, 3).setNumberFormat('#,##0');
    
    // ===== FORMATAÇÃO CONDICIONAL - barras nas % =====
    for (var row = 7; row < 7 + linhas.length; row++) {
      var pctLocal = sheet.getRange(row, 5).getValue();
      var pctNaoLocal = sheet.getRange(row, 6).getValue();
      
      // Destaca prestadores com 100% local ou 100% não local
      if (pctLocal >= 0.95) {
        sheet.getRange(row, 5).setBackground('#DDD6FE'); // Lavanda
      }
      if (pctNaoLocal >= 0.95) {
        sheet.getRange(row, 6).setBackground('#A7F3D0'); // Verde claro
      }
    }
    
    // ===== AUTO-AJUSTA COLUNAS =====
    for (var i = 1; i <= headers.length; i++) {
      sheet.autoResizeColumn(i);
    }
    
    // ===== ADICIONA FILTROS =====
    if (linhas.length > 0) {
      sheet.getRange(6, 1, linhas.length + 1, headers.length).createFilter();
    }
    
    // Força a gravação
    SpreadsheetApp.flush();
    Utilities.sleep(500);
    
    Logger.log('>>> Distribuição exportada com sucesso: ' + nomeArquivo);
    
    return {
      sucesso: true,
      url: 'https://docs.google.com/spreadsheets/d/' + ss.getId(),
      mensagem: 'Relatório gerado com sucesso!'
    };
    
  } catch (error) {
    Logger.log('>>> ERRO ao exportar distribuição: ' + error.toString());
    return { sucesso: false, mensagem: error.toString() };
  }
}

/**
 * Ordena array de prestadores para exportação
 */
function ordenarPrestadoresDistribuicao(prestadores, ordenacao) {
  var copia = prestadores.slice();
  
  copia.sort(function(a, b) {
    switch (ordenacao) {
      case 'nome':
        return a.nome.localeCompare(b.nome);
      case 'total-desc':
        return b.total - a.total;
      case 'total-asc':
        return a.total - b.total;
      case 'local-desc':
        var pA = a.total > 0 ? (a.local / a.total) : 0;
        var pB = b.total > 0 ? (b.local / b.total) : 0;
        return pB - pA;
      case 'naolocal-desc':
        var pNA = a.total > 0 ? (a.naoLocal / a.total) : 0;
        var pNB = b.total > 0 ? (b.naoLocal / b.total) : 0;
        return pNB - pNA;
      default:
        return a.nome.localeCompare(b.nome);
    }
  });
  
  return copia;
}

/**
 * Exporta relatório para PDF
 */
function exportarRelatorioPDF(dados) {
  try {
    if (!dados || dados.length === 0) {
      return { sucesso: false, mensagem: 'Nenhum dado para exportar.' };
    }
    
    // Primeiro cria o Excel
    var resultadoExcel = exportarRelatorioExcel(dados);
    
    if (!resultadoExcel.sucesso) {
      return resultadoExcel;
    }
    
    // Abre a planilha criada
    var ssId = resultadoExcel.url.match(/\/d\/([a-zA-Z0-9-_]+)/)[1];
    var ss = SpreadsheetApp.openById(ssId);
    
    // Gera PDF
    var pdfBlob = ss.getAs('application/pdf');
    pdfBlob.setName('Relatorio_Escalas_' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmm') + '.pdf');
    
    // Salva no Drive
    var file = DriveApp.createFile(pdfBlob);
    
    // Define permissão para qualquer pessoa com o link visualizar
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    
    return {
      sucesso: true,
      url: file.getUrl(),
      mensagem: 'PDF gerado com sucesso!'
    };
    
  } catch (error) {
    Logger.log('Erro ao exportar PDF: ' + error.toString());
    return {
      sucesso: false,
      mensagem: error.toString()
    };
  }
}
// ============================================
// FUNÇÕES DE COMPARAÇÃO FPO × SISREG
// ============================================

/**
 * Lê os dados da aba Dados FPO
 */
function lerDadosFPO() {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName('Dados FPO');
    
    if (!sheet) {
      Logger.log('>>> Aba "Dados FPO" não encontrada');
      return [];
    }
    
    const values = sheet.getDataRange().getValues();
    
    if (values.length <= 3) { // Cabeçalho + descrição + linha 3
      return [];
    }
    
    const dados = [];
    // Começa na linha 4 (índice 3) pois linhas 1-3 são cabeçalho/descrição
    for (let i = 3; i < values.length; i++) {
      const cnes = (values[i][0] || '').toString().trim();
      const codigoSigtap = (values[i][2] || '').toString().trim();
      const qtdContratada = parseFloat(values[i][4]) || 0;
      
      if (cnes && codigoSigtap && qtdContratada > 0) {
        dados.push({
          cnes: cnes,
          nome_prestador: (values[i][1] || '').toString().trim(),
          codigo_sigtap: codigoSigtap,
          nome_procedimento: (values[i][3] || '').toString().trim(),
          qtd_contratada: qtdContratada,
          competencia: (values[i][5] || '').toString().trim()
        });
      }
    }
    
    Logger.log('>>> lerDadosFPO: ' + dados.length + ' registros');
    return dados;
  } catch (error) {
    Logger.log('>>> ERRO em lerDadosFPO: ' + error.toString());
    return [];
  }
}

/**
 * Lê os dados da aba DePara_Procedimentos
 */
function lerDePara() {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName('DePara_Procedimentos');
    
    if (!sheet) {
      Logger.log('>>> Aba "DePara_Procedimentos" não encontrada');
      return {};
    }
    
    const values = sheet.getDataRange().getValues();
    
    if (values.length <= 3) {
      return {};
    }
    
    const dePara = {};
    // Começa na linha 4 (índice 3)
    for (let i = 3; i < values.length; i++) {
      const codigoInterno = (values[i][0] || '').toString().trim();
      const codigoSigtap = (values[i][1] || '').toString().trim();
      const status = (values[i][4] || '').toString().toLowerCase().trim();
      
      if (codigoInterno && codigoSigtap && status === 'ativo') {
        dePara[codigoInterno] = codigoSigtap;
      }
    }
    
    Logger.log('>>> lerDePara: ' + Object.keys(dePara).length + ' vinculações ativas');
    return dePara;
  } catch (error) {
    Logger.log('>>> ERRO em lerDePara: ' + error.toString());
    return {};
  }
}

/**
 * Retorna a comparação FPO × SISREG
 * VERSÃO ATUALIZADA: Considera vigência das escalas no cálculo mensal
 * @param {number} mesReferencia - Mês de referência (1-12)
 * @param {number} anoReferencia - Ano de referência
 */
function getComparacaoFpoSisreg(mesReferencia, anoReferencia) {
  try {
    Logger.log('>>> getComparacaoFpoSisreg: INÍCIO - Mês: ' + mesReferencia + '/' + anoReferencia);
    
    const permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return { erro: true, mensagem: permissao.mensagem };
    }
    
    // Se não informou mês/ano, usa o atual
    if (!mesReferencia || !anoReferencia) {
      var hoje = new Date();
      mesReferencia = hoje.getMonth() + 1;
      anoReferencia = hoje.getFullYear();
    }
    
    // 1. Carregar dados
    const dadosSisreg = lerDadosPlanilha();
    const dadosFpo = lerDadosFPO();
    const dePara = lerDePara();
    
    if (dadosFpo.length === 0) {
      return { erro: true, mensagem: 'Aba "Dados FPO" não encontrada ou vazia.' };
    }
    
    // 2. Identificar escalas compartilhadas e contar procedimentos por escala
    const escalasProcedimentos = {};  // escala_codigo -> Set de item_codigo
    const escalasVagas = {};          // escala_codigo -> total de vagas da escala
    
    dadosSisreg.forEach(function(d) {
      const status = (d.escala_status || '').toString().toLowerCase().trim();
      if (status !== 'ativo' && status !== 'ativa' && status !== 'expirado' && status !== 'expirada') return;
      
      const escalaCodigo = (d.escala_codigo || '').toString().trim();
      const itemCodigo = (d.item_codigo || '').toString().trim();
      
      if (!escalaCodigo || !itemCodigo) return;
      
      // Conta procedimentos únicos por escala
      if (!escalasProcedimentos[escalaCodigo]) {
        escalasProcedimentos[escalaCodigo] = new Set();
      }
      escalasProcedimentos[escalaCodigo].add(itemCodigo);
      
      // Armazena vagas da escala (pega da primeira ocorrência)
      if (!escalasVagas[escalaCodigo]) {
        const rede = parseFloat(d['Rede'] || 0);
        const retorno = parseFloat(d['Retorno '] || d['Retorno'] || 0);
        const reserva = parseFloat(d['Reserva'] || 0);
        escalasVagas[escalaCodigo] = rede + retorno + reserva;
      }
    });
    
    // Converte Sets para contagem
    const escalasQtdProcedimentos = {};
    Object.keys(escalasProcedimentos).forEach(function(escala) {
      escalasQtdProcedimentos[escala] = escalasProcedimentos[escala].size;
    });
    
    Logger.log('>>> Escalas identificadas: ' + Object.keys(escalasQtdProcedimentos).length);
    
    // 3. Agrupar SISREG por CNES + SIGTAP (COM DIVISÃO PROPORCIONAL, BLOQUEIOS E VIGÊNCIA)
    const sisregAgrupado = {};
    const procedimentosCompartilhados = new Set();
    const escalasContabilizadas = {}; // Para evitar duplicação de escalas compartilhadas

    dadosSisreg.forEach(function(d) {
      const status = (d.escala_status || '').toString().toLowerCase().trim();
      if (status !== 'ativo' && status !== 'ativa' && status !== 'expirado' && status !== 'expirada') return;
      
      const cnes = (d.unidade_codigo || '').toString().trim();
      const codigoInterno = (d.item_codigo || '').toString().trim();
      const nomeProcedimento = (d.item_nome || '').toString().trim();
      const nomePrestador = (d.unidade_nome || '').toString().trim();
      const escalaCodigo = (d.escala_codigo || '').toString().trim();
      
      if (!cnes || !codigoInterno) return;
      
      // Converte codigo_interno para codigo_sigtap usando DePara
      const codigoSigtap = dePara[codigoInterno] || null;
      
      // Chave única para verificar duplicação
      const chave = cnes + '|' + (codigoSigtap || 'SEM_SIGTAP_' + codigoInterno);
      
      // Inicializa estrutura de controle de escalas
      if (!escalasContabilizadas[chave]) {
        escalasContabilizadas[chave] = new Set();
      }
      
      // Verifica se esta escala já foi contabilizada para esta combinação
      if (escalaCodigo && escalasContabilizadas[chave].has(escalaCodigo)) {
        return; // Escala já contabilizada, pula
      }
      
      // Marca escala como contabilizada
      if (escalaCodigo) {
        escalasContabilizadas[chave].add(escalaCodigo);
      }
      
      // *** NOVA LÓGICA: Calcula semanas no mês baseado na vigência ***
      const vigenciaInicial = d.vigencia_inicial;
      const vigenciaFinal = d.vigencia_final;
      const semanasNoMes = calcularSemanasNoMes(vigenciaInicial, vigenciaFinal, mesReferencia, anoReferencia);
      
      // Se a escala não está ativa neste mês, pula
      if (semanasNoMes === 0) {
        return;
      }
      
      // Calcula vagas totais da linha (semanal)
      const rede = parseFloat(d['Rede'] || 0);
      const retorno = parseFloat(d['Retorno '] || d['Retorno'] || 0);
      const reserva = parseFloat(d['Reserva'] || 0);
      let totalSemanal = rede + retorno + reserva;
      
      // Verifica bloqueio
      const temBloqueio = (d.tem_afastamento_ativo || '').toString().toUpperCase().trim() === 'SIM';
      let semanasComBloqueio = 0;
      
      if (temBloqueio) {
        const dtInicio = d.dt_inicio_afastamento;
        const dtFim = d.dt_fim_afastamento;
        
        if (dtInicio && dtFim) {
          let dataInicio = converterParaData(dtInicio);
          let dataFim = converterParaData(dtFim);
          
          if (dataInicio && dataFim && !isNaN(dataInicio.getTime()) && !isNaN(dataFim.getTime())) {
            // Calcula bloqueio apenas dentro do mês de referência
            const primeiroDiaMes = new Date(anoReferencia, mesReferencia - 1, 1);
            const ultimoDiaMes = new Date(anoReferencia, mesReferencia, 0);
            
            // Ajusta datas do bloqueio para o mês de referência
            const inicioBloqueioEfetivo = dataInicio > primeiroDiaMes ? dataInicio : primeiroDiaMes;
            const fimBloqueioEfetivo = dataFim < ultimoDiaMes ? dataFim : ultimoDiaMes;
            
            if (inicioBloqueioEfetivo <= fimBloqueioEfetivo) {
              const diffDias = Math.ceil((fimBloqueioEfetivo - inicioBloqueioEfetivo) / (1000 * 60 * 60 * 24)) + 1;
              semanasComBloqueio = Math.min(semanasNoMes, Math.ceil(diffDias / 7));
            }
          }
        } else {
          // Se não tem datas específicas, considera bloqueio total nas semanas ativas
          semanasComBloqueio = semanasNoMes;
        }
      }
      
      // Aplica divisão proporcional se escala compartilhada
      const qtdProcedimentosNaEscala = escalasQtdProcedimentos[escalaCodigo] || 1;
      let isCompartilhada = false;
      
      if (qtdProcedimentosNaEscala > 1) {
        totalSemanal = totalSemanal / qtdProcedimentosNaEscala;
        isCompartilhada = true;
        procedimentosCompartilhados.add(chave);
      }
      
      // *** Calcula total MENSAL baseado nas semanas ativas no mês ***
      const totalMensal = totalSemanal * semanasNoMes;
      const totalBloqueadoMensal = totalSemanal * semanasComBloqueio;
      
      if (!sisregAgrupado[chave]) {
        sisregAgrupado[chave] = {
          cnes: cnes,
          nome_prestador: nomePrestador,
          codigo_sigtap: codigoSigtap,
          codigo_interno: codigoInterno,
          nome_procedimento: nomeProcedimento,
          total_mensal: 0,
          total_mensal_bloqueado: 0,
          tem_vinculo: !!codigoSigtap,
          is_compartilhada: isCompartilhada,
          tem_bloqueio: false,
          bloqueio_total: false
        };
      }
      
      sisregAgrupado[chave].total_mensal += totalMensal;
      
      // Adiciona vagas bloqueadas
      if (temBloqueio) {
        sisregAgrupado[chave].tem_bloqueio = true;
        sisregAgrupado[chave].total_mensal_bloqueado += totalBloqueadoMensal;
        
        // Se bloqueio cobre todas as semanas ativas, marca como bloqueio total
        if (semanasComBloqueio >= semanasNoMes) {
          sisregAgrupado[chave].bloqueio_total = true;
        }
      }
      
      if (isCompartilhada) {
        sisregAgrupado[chave].is_compartilhada = true;
      }
    });
    
    // 4. Agrupar FPO por CNES + SIGTAP
    const fpoAgrupado = {};
    
    dadosFpo.forEach(function(d) {
      const chave = d.cnes + '|' + d.codigo_sigtap;
      
      if (!fpoAgrupado[chave]) {
        fpoAgrupado[chave] = {
          cnes: d.cnes,
          nome_prestador: d.nome_prestador,
          codigo_sigtap: d.codigo_sigtap,
          nome_procedimento: d.nome_procedimento,
          qtd_contratada: 0
        };
      }
      
      fpoAgrupado[chave].qtd_contratada += d.qtd_contratada;
    });
    
    // 5. Fazer a comparação
    const comparacao = {};
    const alertas = {
      somenteSisreg: [],
      somenteFpo: []
    };
    
    // 5.1 Processar todos do SISREG
    Object.keys(sisregAgrupado).forEach(function(chave) {
      const sisreg = sisregAgrupado[chave];
      const totalMensal = Math.round(sisreg.total_mensal);
      
      if (!sisreg.tem_vinculo) {
        alertas.somenteSisreg.push({
          cnes: sisreg.cnes,
          nome_prestador: sisreg.nome_prestador,
          codigo_interno: sisreg.codigo_interno,
          nome_procedimento: sisreg.nome_procedimento,
          implantado: totalMensal,
          motivo: 'Sem vínculo no DePara',
          is_compartilhada: sisreg.is_compartilhada
        });
        return;
      }
      
      const fpo = fpoAgrupado[chave];
      
      if (!comparacao[sisreg.cnes]) {
        comparacao[sisreg.cnes] = {
          cnes: sisreg.cnes,
          nome_prestador: sisreg.nome_prestador,
          total_contratado: 0,
          total_implantado: 0,
          total_bloqueado: 0,
          total_disponivel: 0,
          procedimentos: []
        };
      }

      const contratado = fpo ? fpo.qtd_contratada : 0;
      const implantado = totalMensal;
      const bloqueado = Math.round(sisreg.total_mensal_bloqueado);
      const disponivel = implantado - bloqueado;
      const diferenca = implantado - contratado;
      const diferencaDisponivel = disponivel - contratado;
      const percentual = contratado > 0 ? Math.round((implantado / contratado) * 100) : (implantado > 0 ? 999 : 0);
      const percentualDisponivel = contratado > 0 ? Math.round((disponivel / contratado) * 100) : (disponivel > 0 ? 999 : 0);

      comparacao[sisreg.cnes].total_implantado += implantado;
      comparacao[sisreg.cnes].total_contratado += contratado;
      comparacao[sisreg.cnes].total_bloqueado += bloqueado;

      // NOVO: Para o cálculo do percentual, limita disponível ao máximo do contratado
      var disponivel_para_percentual = contratado > 0 ? Math.min(disponivel, contratado) : disponivel;
      comparacao[sisreg.cnes].total_disponivel += disponivel;
      comparacao[sisreg.cnes].total_disponivel_limitado = (comparacao[sisreg.cnes].total_disponivel_limitado || 0) + disponivel_para_percentual;

      comparacao[sisreg.cnes].procedimentos.push({
        codigo_sigtap: sisreg.codigo_sigtap,
        nome_procedimento: fpo ? fpo.nome_procedimento : sisreg.nome_procedimento,
        contratado: contratado,
        implantado: implantado,
        bloqueado: bloqueado,
        disponivel: disponivel,
        diferenca: diferenca,
        diferenca_disponivel: diferencaDisponivel,
        percentual: percentual,
        percentual_disponivel: percentualDisponivel,
        status: contratado === 0 ? 'sem_contrato' : (percentualDisponivel >= 100 ? 'ok' : (percentualDisponivel >= 80 ? 'atencao' : 'critico')),
        is_compartilhada: sisreg.is_compartilhada,
        tem_bloqueio: sisreg.tem_bloqueio,
        bloqueio_total: sisreg.bloqueio_total
      });
      
      if (!fpo) {
        alertas.somenteSisreg.push({
          cnes: sisreg.cnes,
          nome_prestador: sisreg.nome_prestador,
          codigo_sigtap: sisreg.codigo_sigtap,
          nome_procedimento: sisreg.nome_procedimento,
          implantado: implantado,
          motivo: 'Não existe na FPO',
          is_compartilhada: sisreg.is_compartilhada
        });
      }
    });
    
    // 5.2 Verificar itens da FPO que não estão no SISREG
    Object.keys(fpoAgrupado).forEach(function(chave) {
      const fpo = fpoAgrupado[chave];
      
      if (!sisregAgrupado[chave]) {
        if (!comparacao[fpo.cnes]) {
          comparacao[fpo.cnes] = {
            cnes: fpo.cnes,
            nome_prestador: fpo.nome_prestador,
            total_contratado: 0,
            total_implantado: 0,
            total_bloqueado: 0,
            total_disponivel: 0,
            procedimentos: []
          };
        }
        
        comparacao[fpo.cnes].total_contratado += fpo.qtd_contratada;
        
        comparacao[fpo.cnes].procedimentos.push({
          codigo_sigtap: fpo.codigo_sigtap,
          nome_procedimento: fpo.nome_procedimento,
          contratado: fpo.qtd_contratada,
          implantado: 0,
          bloqueado: 0,
          disponivel: 0,
          diferenca: -fpo.qtd_contratada,
          diferenca_disponivel: -fpo.qtd_contratada,
          percentual: 0,
          percentual_disponivel: 0,
          status: 'nao_implantado',
          is_compartilhada: false,
          tem_bloqueio: false,
          bloqueio_total: false
        });
        
        alertas.somenteFpo.push({
          cnes: fpo.cnes,
          nome_prestador: fpo.nome_prestador,
          codigo_sigtap: fpo.codigo_sigtap,
          nome_procedimento: fpo.nome_procedimento,
          contratado: fpo.qtd_contratada,
          motivo: 'Não implantado no SISREG',
          is_compartilhada: false
        });
      }
    });
    
    // 6. Calcular percentuais dos prestadores e converter para array
    const resultado = [];
    
    Object.keys(comparacao).forEach(function(cnes) {
      const p = comparacao[cnes];
      p.diferenca = p.total_implantado - p.total_contratado;
      p.percentual = p.total_contratado > 0 ? Math.round((p.total_implantado / p.total_contratado) * 100) : 0;
      // USA o valor limitado para calcular o percentual (máximo 100% por procedimento)
      var disponivel_para_calc = p.total_disponivel_limitado !== undefined ? p.total_disponivel_limitado : p.total_disponivel;
      p.percentual_disponivel = p.total_contratado > 0 ? Math.round((disponivel_para_calc / p.total_contratado) * 100) : 0;
      // Limita o percentual geral a no máximo 100%
      p.percentual_disponivel = Math.min(p.percentual_disponivel, 100);
      p.status = p.percentual_disponivel >= 100 ? 'ok' : (p.percentual_disponivel >= 80 ? 'atencao' : 'critico');
      
      p.tem_compartilhada = p.procedimentos.some(function(proc) { return proc.is_compartilhada; });
      
      resultado.push(p);
    });
    
    // Ordena por nome do prestador
    resultado.sort(function(a, b) {
      return a.nome_prestador.localeCompare(b.nome_prestador);
    });
    
    Logger.log('>>> getComparacaoFpoSisreg: FIM - ' + resultado.length + ' prestadores');
    
    return {
      erro: false,
      prestadores: resultado,
      alertas: alertas,
      mes_referencia: mesReferencia,
      ano_referencia: anoReferencia,
      resumo: {
        total_prestadores: resultado.length,
        total_contratado: resultado.reduce(function(sum, p) { return sum + p.total_contratado; }, 0),
        total_implantado: resultado.reduce(function(sum, p) { return sum + p.total_implantado; }, 0),
        total_bloqueado: resultado.reduce(function(sum, p) { return sum + p.total_bloqueado; }, 0),
        total_disponivel: resultado.reduce(function(sum, p) { return sum + p.total_disponivel; }, 0),
        // NOVO: Total limitado para cálculo de percentual
        total_disponivel_limitado: resultado.reduce(function(sum, p) { return sum + (p.total_disponivel_limitado || p.total_disponivel); }, 0),
        sem_vinculo: alertas.somenteSisreg.filter(function(a) { return a.motivo === 'Sem vínculo no DePara'; }).length,
        nao_implantados: alertas.somenteFpo.length
      }
    };
    
  } catch (error) {
    Logger.log('>>> ERRO em getComparacaoFpoSisreg: ' + error.toString());
    return { erro: true, mensagem: error.toString() };
  }
}

/**
 * Exporta relatório FPO × SISREG por prestador para Excel
 * @param {number} mesReferencia - Mês de referência (1-12)
 * @param {number} anoReferencia - Ano de referência
 * @param {string} filtroPrestador - Filtro opcional por nome do prestador
 */
function exportarRelatorioFpoPorPrestador(mesReferencia, anoReferencia, filtroPrestador) {
  try {
    Logger.log('>>> exportarRelatorioFpoPorPrestador: INÍCIO');
    
    // Obtém os dados da comparação
    const dados = getComparacaoFpoSisreg(mesReferencia, anoReferencia);
    
    if (dados.erro) {
      return { sucesso: false, mensagem: dados.mensagem };
    }
    
    if (!dados.prestadores || dados.prestadores.length === 0) {
      return { sucesso: false, mensagem: 'Nenhum dado para exportar.' };
    }
    
    // Aplica filtro de prestador se informado
    let prestadores = dados.prestadores;
    if (filtroPrestador && filtroPrestador.trim() !== '') {
      const filtroLower = filtroPrestador.toLowerCase().trim();
      prestadores = prestadores.filter(function(p) {
        return p.nome_prestador.toLowerCase().indexOf(filtroLower) !== -1;
      });
    }
    
    if (prestadores.length === 0) {
      return { sucesso: false, mensagem: 'Nenhum prestador encontrado com o filtro informado.' };
    }
    
    // Cria uma nova planilha
    const mesesNomes = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    const nomeMes = mesesNomes[mesReferencia - 1];
    const nomeArquivo = 'Relatorio_FPO_SISREG_' + nomeMes + '_' + anoReferencia + '_' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmm');
    
    const ss = SpreadsheetApp.create(nomeArquivo);
    
    // ========== ABA 1: RESUMO POR PRESTADOR ==========
    const sheetResumo = ss.getActiveSheet();
    sheetResumo.setName('Resumo por Prestador');
    
    // Cabeçalho do relatório
    sheetResumo.getRange('A1').setValue('RELATÓRIO FPO × SISREG - ' + nomeMes.toUpperCase() + ' ' + anoReferencia);
    sheetResumo.getRange('A1').setFontSize(14).setFontWeight('bold').setBackground('#8B5CF6').setFontColor('white');
    sheetResumo.getRange('A1:G1').merge();
    
    sheetResumo.getRange('A2').setValue('Gerado em: ' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'dd/MM/yyyy HH:mm'));
    sheetResumo.getRange('A3').setValue('Total de Prestadores: ' + prestadores.length);
    
    // Cabeçalhos da tabela
    const headersResumo = ['CNES', 'Prestador', 'Contratado (FPO)', 'Implantado (SISREG)', 'Bloqueado', 'Disponível', '% Disponível', 'Status'];
    sheetResumo.getRange(5, 1, 1, headersResumo.length).setValues([headersResumo]);
    sheetResumo.getRange(5, 1, 1, headersResumo.length).setFontWeight('bold').setBackground('#A78BFA').setFontColor('white');
    
    // Dados
    const linhasResumo = prestadores.map(function(p) {
      var statusTexto = '';
      if (p.status === 'ok') statusTexto = '✅ OK';
      else if (p.status === 'atencao') statusTexto = '⚠️ Atenção';
      else if (p.status === 'critico') statusTexto = '❌ Crítico';
      
      return [
        p.cnes,
        p.nome_prestador,
        p.total_contratado,
        p.total_implantado,
        p.total_bloqueado,
        p.total_disponivel,
        p.percentual_disponivel + '%',
        statusTexto
      ];
    });
    
    if (linhasResumo.length > 0) {
      sheetResumo.getRange(6, 1, linhasResumo.length, headersResumo.length).setValues(linhasResumo);
      sheetResumo.getRange(6, 3, linhasResumo.length, 4).setNumberFormat('#,##0');
    }
    
    // Formatação condicional por status
    for (var row = 6; row < 6 + linhasResumo.length; row++) {
      var status = sheetResumo.getRange(row, 8).getValue();
      if (status.indexOf('OK') !== -1) {
        sheetResumo.getRange(row, 1, 1, headersResumo.length).setBackground('#D1FAE5');
      } else if (status.indexOf('Atenção') !== -1) {
        sheetResumo.getRange(row, 1, 1, headersResumo.length).setBackground('#FEF3C7');
      } else if (status.indexOf('Crítico') !== -1) {
        sheetResumo.getRange(row, 1, 1, headersResumo.length).setBackground('#FEE2E2');
      }
    }
    
    // Linha de totais
    const linhaTotal = 6 + linhasResumo.length;
    const totalContratado = prestadores.reduce(function(sum, p) { return sum + p.total_contratado; }, 0);
    const totalImplantado = prestadores.reduce(function(sum, p) { return sum + p.total_implantado; }, 0);
    const totalBloqueado = prestadores.reduce(function(sum, p) { return sum + p.total_bloqueado; }, 0);
    const totalDisponivel = prestadores.reduce(function(sum, p) { return sum + p.total_disponivel; }, 0);
    const percentualGeral = totalContratado > 0 ? Math.round((totalDisponivel / totalContratado) * 100) : 0;
    
    sheetResumo.getRange(linhaTotal, 1, 1, headersResumo.length).setValues([['', 'TOTAL GERAL', totalContratado, totalImplantado, totalBloqueado, totalDisponivel, percentualGeral + '%', '']]);
    sheetResumo.getRange(linhaTotal, 1, 1, headersResumo.length).setFontWeight('bold').setBackground('#E5E7EB');
    sheetResumo.getRange(linhaTotal, 3, 1, 4).setNumberFormat('#,##0');
    
    // Auto-ajusta colunas
    for (var i = 1; i <= headersResumo.length; i++) {
      sheetResumo.autoResizeColumn(i);
    }
    
    // Adiciona filtros
    if (linhasResumo.length > 0) {
      sheetResumo.getRange(5, 1, linhasResumo.length + 1, headersResumo.length).createFilter();
    }
    
    // ========== ABA 2: DETALHAMENTO POR PROCEDIMENTO ==========
    const sheetDetalhe = ss.insertSheet('Detalhamento Procedimentos');
    
    // Cabeçalho
    sheetDetalhe.getRange('A1').setValue('DETALHAMENTO POR PROCEDIMENTO - ' + nomeMes.toUpperCase() + ' ' + anoReferencia);
    sheetDetalhe.getRange('A1').setFontSize(14).setFontWeight('bold').setBackground('#8B5CF6').setFontColor('white');
    sheetDetalhe.getRange('A1:J1').merge();
    
    // Cabeçalhos da tabela
    const headersDetalhe = ['CNES', 'Prestador', 'Código SIGTAP', 'Procedimento', 'Contratado', 'Implantado', 'Bloqueado', 'Disponível', '% Disp.', 'Status'];
    sheetDetalhe.getRange(3, 1, 1, headersDetalhe.length).setValues([headersDetalhe]);
    sheetDetalhe.getRange(3, 1, 1, headersDetalhe.length).setFontWeight('bold').setBackground('#A78BFA').setFontColor('white');
    
    // Dados detalhados
    const linhasDetalhe = [];
    prestadores.forEach(function(p) {
      p.procedimentos.forEach(function(proc) {
        var statusTexto = '';
        if (proc.status === 'ok') statusTexto = '✅ OK';
        else if (proc.status === 'atencao') statusTexto = '⚠️ Atenção';
        else if (proc.status === 'critico') statusTexto = '❌ Crítico';
        else if (proc.status === 'nao_implantado') statusTexto = '🚫 Não Implantado';
        else if (proc.status === 'sem_contrato') statusTexto = '📋 Sem Contrato';
        
        linhasDetalhe.push([
          p.cnes,
          p.nome_prestador,
          proc.codigo_sigtap,
          proc.nome_procedimento + (proc.is_compartilhada ? ' ≈' : ''),
          proc.contratado,
          proc.implantado,
          proc.bloqueado,
          proc.disponivel,
          proc.percentual_disponivel + '%',
          statusTexto
        ]);
      });
    });
    
    if (linhasDetalhe.length > 0) {
      sheetDetalhe.getRange(4, 1, linhasDetalhe.length, headersDetalhe.length).setValues(linhasDetalhe);
      sheetDetalhe.getRange(4, 5, linhasDetalhe.length, 4).setNumberFormat('#,##0');
    }
    
    // Auto-ajusta colunas
    for (var j = 1; j <= headersDetalhe.length; j++) {
      sheetDetalhe.autoResizeColumn(j);
    }
    
    // Adiciona filtros
    if (linhasDetalhe.length > 0) {
      sheetDetalhe.getRange(3, 1, linhasDetalhe.length + 1, headersDetalhe.length).createFilter();
    }
    
    // Formatação condicional
    for (var rowD = 4; rowD < 4 + linhasDetalhe.length; rowD++) {
      var statusD = sheetDetalhe.getRange(rowD, 10).getValue();
      if (statusD.indexOf('OK') !== -1) {
        sheetDetalhe.getRange(rowD, 1, 1, headersDetalhe.length).setBackground('#D1FAE5');
      } else if (statusD.indexOf('Atenção') !== -1) {
        sheetDetalhe.getRange(rowD, 1, 1, headersDetalhe.length).setBackground('#FEF3C7');
      } else if (statusD.indexOf('Crítico') !== -1 || statusD.indexOf('Não Implantado') !== -1) {
        sheetDetalhe.getRange(rowD, 1, 1, headersDetalhe.length).setBackground('#FEE2E2');
      }
    }
    
    Logger.log('>>> Relatório FPO exportado com sucesso: ' + nomeArquivo);
    
    // Força a gravação de todas as alterações pendentes
    SpreadsheetApp.flush();

    // Pequena pausa para garantir que tudo foi salvo
    Utilities.sleep(500);

    Logger.log('>>> Relatório gerado: ' + ss.getUrl());

    return {
      sucesso: true,
      url: 'https://docs.google.com/spreadsheets/d/' + ss.getId(),
      mensagem: 'Relatório gerado com sucesso!'
    };
    
  } catch (error) {
    Logger.log('>>> ERRO ao exportar relatório FPO: ' + error.toString());
    return {
      sucesso: false,
      mensagem: error.toString()
    };
  }
}

// ============================================
// FUNÇÕES DE COMPARAÇÃO TETO × OFERTA
// ============================================

/**
 * Lê os dados da aba Tabela_Teto
 */
function lerTabelaTeto() {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName('Tabela_Teto');
    
    if (!sheet) {
      Logger.log('>>> Aba "Tabela_Teto" não encontrada');
      return {};
    }
    
    const values = sheet.getDataRange().getValues();
    
    if (values.length <= 1) {
      return {};
    }
    
    // Identifica índices das colunas pelo cabeçalho
    const headers = values[0];
    let idxUnidade = -1;
    let idxProcedimento = -1;
    let idxTeto = -1;
    
    for (let i = 0; i < headers.length; i++) {
      const header = (headers[i] || '').toString().toLowerCase().trim();
      if (header === 'unidade_codigo' || header === 'cnes') {
        idxUnidade = i;
      } else if (header === 'procedimento_codigo' || header === 'codigo_procedimento') {
        idxProcedimento = i;
      } else if (header === 'teto' || header === 'valor_teto' || header === 'qtd_teto') {
        idxTeto = i;
      }
    }
    
    // Se não encontrou pelo nome, assume posições padrão
    if (idxUnidade === -1) idxUnidade = 0;
    if (idxProcedimento === -1) idxProcedimento = 1;
    if (idxTeto === -1) idxTeto = 2;
    
    const tetos = {};
    
    // Começa na linha 2 (índice 1) para pular cabeçalho
    for (let i = 1; i < values.length; i++) {
      const unidadeCodigo = (values[i][idxUnidade] || '').toString().trim();
      const procedimentoCodigo = (values[i][idxProcedimento] || '').toString().trim();
      const valorTeto = parseFloat(values[i][idxTeto]) || 0;
      
      if (unidadeCodigo && procedimentoCodigo) {
        const chave = unidadeCodigo + '|' + procedimentoCodigo;
        tetos[chave] = {
          unidade_codigo: unidadeCodigo,
          procedimento_codigo: procedimentoCodigo,
          valor_teto: valorTeto
        };
      }
    }
    
    Logger.log('>>> lerTabelaTeto: ' + Object.keys(tetos).length + ' registros de teto');
    return tetos;
  } catch (error) {
    Logger.log('>>> ERRO em lerTabelaTeto: ' + error.toString());
    return {};
  }
}

/**
 * Retorna a comparação Teto × Oferta
 * VERSÃO CORRIGIDA: Conta cada escala apenas uma vez, mesmo se compartilhada
 */
function getComparacaoTetoOferta() {
  try {
    Logger.log('>>> getComparacaoTetoOferta: INÍCIO');
    
    const permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return { erro: true, mensagem: permissao.mensagem };
    }
    
    // 1. Carregar dados
    const dadosSisreg = lerDadosPlanilha();
    const tabelaTeto = lerTabelaTeto();
    
    if (Object.keys(tabelaTeto).length === 0) {
      return { erro: true, mensagem: 'Aba "Tabela_Teto" não encontrada ou vazia.' };
    }
    
    Logger.log('>>> Dados SISREG: ' + dadosSisreg.length + ' registros');
    Logger.log('>>> Tabela Teto: ' + Object.keys(tabelaTeto).length + ' registros');
    
    // 2. Agrupar ofertas por unidade_codigo + procedimento_codigo
    // CORREÇÃO: Usar Set para rastrear escalas já contabilizadas
    const ofertasAgrupadas = {};
    const prestadoresInfo = {};
    const escalasContabilizadas = {}; // Chave: unidade_codigo|procedimento_codigo -> Set de escala_codigo
    
    dadosSisreg.forEach(function(d) {
      // Filtra apenas ativos
      const status = (d.escala_status || '').toString().toLowerCase().trim();
      if (status !== 'ativo' && status !== 'ativa') return;
      
      const unidadeCodigo = (d.unidade_codigo || '').toString().trim();
      const procedimentoCodigo = (d.procedimento_codigo || '').toString().trim();
      const nomePrestador = (d.unidade_nome || '').toString().trim();
      const nomeProcedimento = (d.procedimento_nome || '').toString().trim();
      const escalaCodigo = (d.escala_codigo || '').toString().trim();
      
      if (!unidadeCodigo || !procedimentoCodigo) return;
      
      // Armazena info do prestador
      if (!prestadoresInfo[unidadeCodigo]) {
        prestadoresInfo[unidadeCodigo] = nomePrestador;
      }
      
      // Chave única para agrupamento
      const chave = unidadeCodigo + '|' + procedimentoCodigo;
      
      // Inicializa estruturas se não existirem
      if (!escalasContabilizadas[chave]) {
        escalasContabilizadas[chave] = new Set();
      }
      
      if (!ofertasAgrupadas[chave]) {
        ofertasAgrupadas[chave] = {
          unidade_codigo: unidadeCodigo,
          nome_prestador: nomePrestador,
          procedimento_codigo: procedimentoCodigo,
          nome_procedimento: nomeProcedimento,
          total_oferta: 0,
          qtd_escalas: 0,
          escalas_unicas: new Set()
        };
      }
      
      // CORREÇÃO PRINCIPAL: Verifica se esta escala já foi contabilizada para esta combinação
      if (escalaCodigo && escalasContabilizadas[chave].has(escalaCodigo)) {
        // Escala já contabilizada, pula para não somar duplicado
        Logger.log('>>> Escala ' + escalaCodigo + ' já contabilizada para ' + chave + ', pulando...');
        return;
      }
      
      // Marca escala como contabilizada
      if (escalaCodigo) {
        escalasContabilizadas[chave].add(escalaCodigo);
        ofertasAgrupadas[chave].escalas_unicas.add(escalaCodigo);
      }
      
      // Soma as vagas originais (apenas uma vez por escala)
      const vagasPrimeiraVez = parseFloat(d['vagas_primeira_vez_original'] || 0);
      const vagasRetorno = parseFloat(d['vagas_retorno_original'] || 0);
      const vagasReserva = parseFloat(d['vagas_reserva_original'] || 0);
      const totalVagas = vagasPrimeiraVez + vagasRetorno + vagasReserva;
      
      ofertasAgrupadas[chave].total_oferta += totalVagas;
      ofertasAgrupadas[chave].qtd_escalas += 1;
    });
    
    // Converte Set para número na contagem de escalas únicas
    Object.keys(ofertasAgrupadas).forEach(function(chave) {
      ofertasAgrupadas[chave].qtd_escalas = ofertasAgrupadas[chave].escalas_unicas.size;
      delete ofertasAgrupadas[chave].escalas_unicas; // Remove o Set para não enviar ao frontend
    });
    
    Logger.log('>>> Ofertas agrupadas: ' + Object.keys(ofertasAgrupadas).length + ' combinações');
    
    // 3. Fazer a comparação e agrupar por prestador
    const prestadores = {};
    const alertas = {
      semTeto: [],      // Procedimentos sem teto cadastrado
      excedidos: []     // Procedimentos que excedem o teto
    };
    
    // 3.1 Processar ofertas e comparar com teto
    Object.keys(ofertasAgrupadas).forEach(function(chave) {
      const oferta = ofertasAgrupadas[chave];
      const teto = tabelaTeto[chave];
      
      const unidadeCodigo = oferta.unidade_codigo;
      
      // Inicializa prestador se não existir
      if (!prestadores[unidadeCodigo]) {
        prestadores[unidadeCodigo] = {
          unidade_codigo: unidadeCodigo,
          nome_prestador: oferta.nome_prestador,
          total_procedimentos: 0,
          total_oferta: 0,
          total_teto: 0,
          qtd_ok: 0,
          qtd_atencao: 0,
          qtd_excedido: 0,
          qtd_sem_teto: 0,
          procedimentos: []
        };
      }
      
      const p = prestadores[unidadeCodigo];
      p.total_procedimentos += 1;
      p.total_oferta += oferta.total_oferta;
      
      let valorTeto = 0;
      let status = '';
      let diferenca = 0;
      let percentual = 0;
      let temTeto = false;
      
      if (teto) {
        temTeto = true;
        valorTeto = teto.valor_teto;
        p.total_teto += valorTeto;
        diferenca = oferta.total_oferta - valorTeto;
        
        // CORREÇÃO: Se teto é 0 e tem oferta, considera como excedido (percentual infinito)
        if (valorTeto === 0) {
          percentual = oferta.total_oferta > 0 ? 999 : 0;
        } else {
          percentual = Math.round((oferta.total_oferta / valorTeto) * 100);
        }
        
        // CORREÇÃO: Teto 0 com qualquer oferta > 0 é excedido
        if (valorTeto === 0 && oferta.total_oferta > 0) {
          status = 'excedido';
          p.qtd_excedido += 1;
          
          alertas.excedidos.push({
            unidade_codigo: unidadeCodigo,
            nome_prestador: oferta.nome_prestador,
            procedimento_codigo: oferta.procedimento_codigo,
            nome_procedimento: oferta.nome_procedimento,
            teto: valorTeto,
            oferta: Math.round(oferta.total_oferta),
            excesso: Math.round(diferenca)
          });
        } else if (percentual <= 90) {
          status = 'ok';
          p.qtd_ok += 1;
        } else if (percentual <= 100) {
          status = 'atencao';
          p.qtd_atencao += 1;
        } else {
          status = 'excedido';
          p.qtd_excedido += 1;
          
          alertas.excedidos.push({
            unidade_codigo: unidadeCodigo,
            nome_prestador: oferta.nome_prestador,
            procedimento_codigo: oferta.procedimento_codigo,
            nome_procedimento: oferta.nome_procedimento,
            teto: valorTeto,
            oferta: Math.round(oferta.total_oferta),
            excesso: Math.round(diferenca)
          });
        }
      }

      p.procedimentos.push({
        procedimento_codigo: oferta.procedimento_codigo,
        nome_procedimento: oferta.nome_procedimento,
        teto: valorTeto,
        oferta: Math.round(oferta.total_oferta),
        diferenca: Math.round(diferenca),
        percentual: percentual,
        status: status,
        tem_teto: temTeto,
        qtd_escalas: oferta.qtd_escalas
      });
    });
    
    // 3.2 Verificar tetos que não têm oferta (procedimentos não implantados)
    Object.keys(tabelaTeto).forEach(function(chave) {
      if (!ofertasAgrupadas[chave]) {
        const teto = tabelaTeto[chave];
        const unidadeCodigo = teto.unidade_codigo;
        const nomePrestador = prestadoresInfo[unidadeCodigo] || 'Prestador ' + unidadeCodigo;
        
        // Inicializa prestador se não existir
        if (!prestadores[unidadeCodigo]) {
          prestadores[unidadeCodigo] = {
            unidade_codigo: unidadeCodigo,
            nome_prestador: nomePrestador,
            total_procedimentos: 0,
            total_oferta: 0,
            total_teto: 0,
            qtd_ok: 0,
            qtd_atencao: 0,
            qtd_excedido: 0,
            qtd_sem_teto: 0,
            procedimentos: []
          };
        }
        
        const p = prestadores[unidadeCodigo];
        p.total_procedimentos += 1;
        p.total_teto += teto.valor_teto;
        p.qtd_ok += 1; // Sem oferta = não excede
        
        p.procedimentos.push({
          procedimento_codigo: teto.procedimento_codigo,
          nome_procedimento: 'Procedimento ' + teto.procedimento_codigo,
          teto: teto.valor_teto,
          oferta: 0,
          diferenca: -teto.valor_teto,
          percentual: 0,
          status: 'sem_oferta',
          tem_teto: true,
          qtd_escalas: 0
        });
      }
    });
    
    // 4. Calcular status geral de cada prestador e converter para array
    const resultado = [];
    
    Object.keys(prestadores).forEach(function(unidadeCodigo) {
      const p = prestadores[unidadeCodigo];
      
      // Arredonda totais
      p.total_oferta = Math.round(p.total_oferta);
      p.total_teto = Math.round(p.total_teto);
      
      // Calcula percentual geral
      p.percentual_geral = p.total_teto > 0 ? Math.round((p.total_oferta / p.total_teto) * 100) : 0;
      
      // Define status geral
      if (p.qtd_excedido > 0) {
        p.status = 'excedido';
      } else if (p.qtd_atencao > 0 || p.qtd_sem_teto > 0) {
        p.status = 'atencao';
      } else {
        p.status = 'ok';
      }
      
      // Ordena procedimentos: excedidos primeiro, depois atenção, depois sem_teto, depois ok
      p.procedimentos.sort(function(a, b) {
        const ordem = { 'excedido': 0, 'atencao': 1, 'sem_teto': 2, 'ok': 3, 'sem_oferta': 4 };
        return (ordem[a.status] || 5) - (ordem[b.status] || 5);
      });
      
      resultado.push(p);
    });
    
    // Ordena prestadores por nome
    resultado.sort(function(a, b) {
      return a.nome_prestador.localeCompare(b.nome_prestador);
    });
    
    // 5. Calcula resumo geral
    const resumo = {
      total_prestadores: resultado.length,
      total_procedimentos: resultado.reduce(function(sum, p) { return sum + p.total_procedimentos; }, 0),
      total_oferta: resultado.reduce(function(sum, p) { return sum + p.total_oferta; }, 0),
      total_teto: resultado.reduce(function(sum, p) { return sum + p.total_teto; }, 0),
      qtd_ok: resultado.reduce(function(sum, p) { return sum + p.qtd_ok; }, 0),
      qtd_atencao: resultado.reduce(function(sum, p) { return sum + p.qtd_atencao; }, 0),
      qtd_excedido: resultado.reduce(function(sum, p) { return sum + p.qtd_excedido; }, 0),
      qtd_sem_teto: resultado.reduce(function(sum, p) { return sum + p.qtd_sem_teto; }, 0),
      prestadores_excedidos: resultado.filter(function(p) { return p.status === 'excedido'; }).length
    };
    
    resumo.percentual_conformidade = resumo.total_procedimentos > 0 
      ? Math.round(((resumo.qtd_ok + resumo.qtd_atencao) / resumo.total_procedimentos) * 100) 
      : 0;
    
    Logger.log('>>> getComparacaoTetoOferta: FIM - ' + resultado.length + ' prestadores');
    
    return {
      erro: false,
      prestadores: resultado,
      alertas: alertas,
      resumo: resumo
    };
    
  } catch (error) {
    Logger.log('>>> ERRO em getComparacaoTetoOferta: ' + error.toString());
    return { erro: true, mensagem: error.toString() };
  }
}

/**
 * Calcula quantas semanas (ocorrências) uma escala tem dentro de um mês específico
 * Como cada escala ocorre 1 vez por semana, conta quantas semanas estão cobertas
 */
function calcularSemanasNoMes(vigenciaInicial, vigenciaFinal, mes, ano) {
  try {
    // Se não tem vigência, considera ativa o mês inteiro (4 semanas)
    if (!vigenciaInicial && !vigenciaFinal) {
      return 4;
    }
    
    // Primeiro e último dia do mês de referência
    var primeiroDiaMes = new Date(ano, mes - 1, 1);
    var ultimoDiaMes = new Date(ano, mes, 0);
    
    // Converte vigências para Date
    var dataInicio = converterParaData(vigenciaInicial);
    var dataFim = converterParaData(vigenciaFinal);
    
    // Se não conseguiu converter, considera ativa o mês inteiro
    if (!dataInicio) dataInicio = new Date(1900, 0, 1);
    if (!dataFim) dataFim = new Date(2100, 11, 31);
    
    // Verifica se a escala está fora do mês completamente
    if (dataFim < primeiroDiaMes || dataInicio > ultimoDiaMes) {
      return 0; // Escala não está ativa neste mês
    }
    
    // Calcula o período efetivo dentro do mês
    var inicioEfetivo = dataInicio > primeiroDiaMes ? dataInicio : primeiroDiaMes;
    var fimEfetivo = dataFim < ultimoDiaMes ? dataFim : ultimoDiaMes;
    
    // Calcula dias ativos no mês
    var diasAtivos = Math.ceil((fimEfetivo - inicioEfetivo) / (1000 * 60 * 60 * 24)) + 1;
    
    // Cada 7 dias = 1 semana (1 ocorrência)
    // Arredonda para cima pois mesmo 1 dia já conta como 1 ocorrência
    var semanas = Math.ceil(diasAtivos / 7);
    
    // Limita a no máximo 5 semanas (alguns meses podem ter 5 ocorrências de um dia)
    return Math.min(semanas, 5);
    
  } catch (error) {
    Logger.log('>>> ERRO em calcularSemanasNoMes: ' + error.toString());
    return 4; // Em caso de erro, considera o mês inteiro
  }
}

// ============================================
// AVALIAÇÃO DE PRESTADORES - CÓDIGO BACKEND
// Adicionar ao arquivo Code.gs
// ============================================

// ============================================
// CONFIGURAÇÃO - Adicionar ao CONFIG existente
// ============================================
// No objeto CONFIG, adicione:
// AVALIACAO_SHEET: 'Dados_Avaliacao'

// ============================================
// FUNÇÃO PARA CRIAR A ABA DE DADOS
// Execute UMA VEZ para criar a estrutura
// ============================================

/**
 * Cria a aba Dados_Avaliacao com a estrutura necessária
 * EXECUTAR UMA VEZ para criar a estrutura
 */
function criarAbaDadosAvaliacao() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sheet = ss.getSheetByName('Dados_Avaliacao');
  
  if (!sheet) {
    sheet = ss.insertSheet('Dados_Avaliacao');
    
    // Cabeçalhos
    const headers = [
      'cnes',
      'nome_prestador', 
      'ano',
      'mes',
      'tipo_fixado',      // Pré-Fixado / Pós-Fixado
      'complexidade',     // ALTA / MÉDIA / FAEC
      'modalidade',       // Ambulatorial / Hospitalar
      'meta',
      'producao',
      'desempenho',       // Decimal (0-1+)
      'classificacao'     // Insatisfatório / Regular / Bom / Ótimo
    ];
    
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    sheet.getRange(1, 1, 1, headers.length).setFontWeight('bold');
    sheet.getRange(1, 1, 1, headers.length).setBackground('#8B5CF6');
    sheet.getRange(1, 1, 1, headers.length).setFontColor('white');
    
    // Validação para classificação
    const regraClassif = SpreadsheetApp.newDataValidation()
      .requireValueInList(['Insatisfatório', 'Regular', 'Bom', 'Ótimo'], true)
      .setAllowInvalid(false)
      .build();
    sheet.getRange('K2:K1000').setDataValidation(regraClassif);
    
    // Validação para tipo_fixado
    const regraTipo = SpreadsheetApp.newDataValidation()
      .requireValueInList(['Pré-Fixado', 'Pós-Fixado'], true)
      .setAllowInvalid(false)
      .build();
    sheet.getRange('E2:E1000').setDataValidation(regraTipo);
    
    // Validação para complexidade
    const regraComplex = SpreadsheetApp.newDataValidation()
      .requireValueInList(['ALTA', 'MÉDIA', 'FAEC'], true)
      .setAllowInvalid(false)
      .build();
    sheet.getRange('F2:F1000').setDataValidation(regraComplex);
    
    // Validação para modalidade
    const regraModal = SpreadsheetApp.newDataValidation()
      .requireValueInList(['Ambulatorial', 'Hospitalar'], true)
      .setAllowInvalid(false)
      .build();
    sheet.getRange('G2:G1000').setDataValidation(regraModal);
    
    // Formata colunas numéricas
    sheet.getRange('H2:I1000').setNumberFormat('#,##0');
    sheet.getRange('J2:J1000').setNumberFormat('0.00%');
    
    // Ajusta largura das colunas
    sheet.setColumnWidth(1, 100);  // cnes
    sheet.setColumnWidth(2, 250);  // nome_prestador
    sheet.setColumnWidth(3, 60);   // ano
    sheet.setColumnWidth(4, 60);   // mes
    sheet.setColumnWidth(5, 100);  // tipo_fixado
    sheet.setColumnWidth(6, 100);  // complexidade
    sheet.setColumnWidth(7, 100);  // modalidade
    sheet.setColumnWidth(8, 100);  // meta
    sheet.setColumnWidth(9, 100);  // producao
    sheet.setColumnWidth(10, 100); // desempenho
    sheet.setColumnWidth(11, 120); // classificacao
    
    // Adiciona dados de exemplo
    const exemplosDados = [
      ['9606823', 'CLÍNICA BEM ESTAR', 2025, 11, 'Pré-Fixado', 'MÉDIA', 'Ambulatorial', 1338, 1412, 1.055, 'Ótimo'],
      ['9606823', 'CLÍNICA BEM ESTAR', 2025, 12, 'Pré-Fixado', 'MÉDIA', 'Ambulatorial', 1338, 996, 0.744, 'Regular'],
      ['9606823', 'CLÍNICA BEM ESTAR', 2026, 1, 'Pré-Fixado', 'MÉDIA', 'Ambulatorial', 1338, 958, 0.716, 'Regular'],
    ];
    
    sheet.getRange(2, 1, exemplosDados.length, exemplosDados[0].length).setValues(exemplosDados);
    
    Logger.log('>>> Aba Dados_Avaliacao criada com sucesso!');
    return 'Aba "Dados_Avaliacao" criada com sucesso! Preencha os dados dos prestadores.';
  } else {
    Logger.log('>>> Aba Dados_Avaliacao já existe.');
    return 'Aba "Dados_Avaliacao" já existe.';
  }
}

// ============================================
// FUNÇÕES DE LEITURA DE DADOS DE AVALIAÇÃO
// ============================================

/**
 * Lê os dados da aba Dados_Avaliacao
 */
function lerDadosAvaliacao() {
  try {
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const sheet = ss.getSheetByName('Dados_Avaliacao');
    
    if (!sheet) {
      Logger.log('>>> Aba "Dados_Avaliacao" não encontrada');
      return [];
    }
    
    const values = sheet.getDataRange().getValues();
    
    if (values.length <= 1) {
      return [];
    }
    
    const headers = values[0];
    const dados = [];
    
    for (let i = 1; i < values.length; i++) {
      const row = {};
      for (let j = 0; j < headers.length; j++) {
        row[headers[j]] = values[i][j];
      }
      
      // Só adiciona se tem dados essenciais
      if (row.cnes && row.nome_prestador && row.ano && row.mes) {
        dados.push(row);
      }
    }
    
    Logger.log('>>> lerDadosAvaliacao: ' + dados.length + ' registros');
    return dados;
  } catch (error) {
    Logger.log('>>> ERRO em lerDadosAvaliacao: ' + error.toString());
    return [];
  }
}

/**
 * Retorna avaliações dos prestadores para um período (trimestre)
 * @param {number} mesReferencia - Mês de referência (1-12)
 * @param {number} anoReferencia - Ano de referência
 */
function getAvaliacaoPrestadores(mesReferencia, anoReferencia) {
  try {
    Logger.log('>>> getAvaliacaoPrestadores: INÍCIO - Mês: ' + mesReferencia + '/' + anoReferencia);
    
    const permissao = verificarPermissao();
    if (!permissao.autorizado) {
      return { erro: true, mensagem: permissao.mensagem };
    }
    
    // Se não informou mês/ano, usa o atual
    if (!mesReferencia || !anoReferencia) {
      var hoje = new Date();
      mesReferencia = hoje.getMonth() + 1;
      anoReferencia = hoje.getFullYear();
    }
    
    const dados = lerDadosAvaliacao();
    
    if (dados.length === 0) {
      return {
        erro: false,
        prestadores: [],
        resumo: {
          totalPrestadores: 0,
          desempenhoGeral: 0,
          qtdSatisfatorio: 0,
          qtdAtencao: 0,
          qtdCritico: 0
        },
        trimestre: [],
        mes_referencia: mesReferencia,
        ano_referencia: anoReferencia
      };
    }
    
    // Calcula o trimestre (mês atual + 2 anteriores)
    const trimestre = calcularTrimestre(mesReferencia, anoReferencia);
    Logger.log('>>> Trimestre: ' + JSON.stringify(trimestre));
    
    // Filtra dados do trimestre
    const dadosTrimestre = dados.filter(function(d) {
      return trimestre.some(function(t) {
        return d.ano === t.ano && d.mes === t.mes;
      });
    });
    
    Logger.log('>>> Dados no trimestre: ' + dadosTrimestre.length);
    
    // Agrupa por prestador (CNES)
    const prestadoresMap = {};
    
    dadosTrimestre.forEach(function(d) {
      const cnes = d.cnes.toString().trim();
      
      if (!prestadoresMap[cnes]) {
        prestadoresMap[cnes] = {
          cnes: cnes,
          nome_prestador: d.nome_prestador,
          categorias: {},
          meses: {},
          totais: {
            meta: 0,
            producao: 0,
            qtdOtimo: 0,
            qtdBom: 0,
            qtdRegular: 0,
            qtdInsatisfatorio: 0
          }
        };
      }
      
      const p = prestadoresMap[cnes];
      
      // Agrupa por categoria (tipo_fixado + complexidade + modalidade)
      const categoria = [d.tipo_fixado, d.complexidade, d.modalidade].filter(Boolean).join(' - ');
      if (!p.categorias[categoria]) {
        p.categorias[categoria] = [];
      }
      p.categorias[categoria].push(d);
      
      // Agrupa por mês
      const mesKey = d.ano + '-' + String(d.mes).padStart(2, '0');
      if (!p.meses[mesKey]) {
        p.meses[mesKey] = {
          ano: d.ano,
          mes: d.mes,
          mesNome: getMesNome(d.mes),
          meta: 0,
          producao: 0,
          desempenho: 0,
          qtdOtimo: 0,
          qtdBom: 0,
          qtdRegular: 0,
          qtdInsatisfatorio: 0
        };
      }
      
      const m = p.meses[mesKey];
      m.meta += parseFloat(d.meta) || 0;
      m.producao += parseFloat(d.producao) || 0;
      
      // Conta classificações
      switch (d.classificacao) {
        case 'Ótimo': m.qtdOtimo++; p.totais.qtdOtimo++; break;
        case 'Bom': m.qtdBom++; p.totais.qtdBom++; break;
        case 'Regular': m.qtdRegular++; p.totais.qtdRegular++; break;
        case 'Insatisfatório': m.qtdInsatisfatorio++; p.totais.qtdInsatisfatorio++; break;
      }
      
      // Totais
      p.totais.meta += parseFloat(d.meta) || 0;
      p.totais.producao += parseFloat(d.producao) || 0;
    });
    
    // Converte para array e calcula métricas
    const prestadores = [];
    
    Object.keys(prestadoresMap).forEach(function(cnes) {
      const p = prestadoresMap[cnes];
      
      // Calcula desempenho geral
      p.desempenhoGeral = p.totais.meta > 0 
        ? Math.round((p.totais.producao / p.totais.meta) * 100) 
        : 0;
      
      // Calcula desempenho por mês
      Object.keys(p.meses).forEach(function(mesKey) {
        const m = p.meses[mesKey];
        m.desempenho = m.meta > 0 ? Math.round((m.producao / m.meta) * 100) : 0;
      });
      
      // Converte meses para array ordenado
      p.mesesArray = Object.values(p.meses).sort(function(a, b) {
        return (a.ano * 100 + a.mes) - (b.ano * 100 + b.mes);
      });
      
      // Converte categorias para array
      p.categoriasArray = Object.keys(p.categorias).map(function(cat) {
        return {
          nome: cat,
          dados: p.categorias[cat]
        };
      });
      
      // Define classificação geral
      p.classificacaoGeral = classificarDesempenho(p.desempenhoGeral / 100);
      
      // Define status
      if (p.totais.qtdInsatisfatorio > 0) {
        p.status = 'critico';
      } else if (p.totais.qtdRegular > 0) {
        p.status = 'atencao';
      } else {
        p.status = 'ok';
      }
      
      // Arredonda totais
      p.totais.meta = Math.round(p.totais.meta);
      p.totais.producao = Math.round(p.totais.producao);
      
      prestadores.push(p);
    });
    
    // Ordena por nome
    prestadores.sort(function(a, b) {
      return a.nome_prestador.localeCompare(b.nome_prestador);
    });
    
    // Calcula resumo geral
    const resumo = {
      totalPrestadores: prestadores.length,
      desempenhoGeral: 0,
      totalMeta: 0,
      totalProducao: 0,
      qtdSatisfatorio: prestadores.filter(function(p) { return p.status === 'ok'; }).length,
      qtdAtencao: prestadores.filter(function(p) { return p.status === 'atencao'; }).length,
      qtdCritico: prestadores.filter(function(p) { return p.status === 'critico'; }).length
    };
    
    prestadores.forEach(function(p) {
      resumo.totalMeta += p.totais.meta;
      resumo.totalProducao += p.totais.producao;
    });
    
    resumo.desempenhoGeral = resumo.totalMeta > 0 
      ? Math.round((resumo.totalProducao / resumo.totalMeta) * 100) 
      : 0;
    
    Logger.log('>>> getAvaliacaoPrestadores: FIM - ' + prestadores.length + ' prestadores');
    
    return {
      erro: false,
      prestadores: prestadores,
      resumo: resumo,
      trimestre: trimestre,
      mes_referencia: mesReferencia,
      ano_referencia: anoReferencia
    };
    
  } catch (error) {
    Logger.log('>>> ERRO em getAvaliacaoPrestadores: ' + error.toString());
    return { erro: true, mensagem: error.toString() };
  }
}

/**
 * Retorna detalhes de avaliação de um prestador específico
 */
function getDetalheAvaliacaoPrestador(cnes, mesReferencia, anoReferencia) {
  try {
    Logger.log('>>> getDetalheAvaliacaoPrestador: CNES=' + cnes);
    
    const dados = lerDadosAvaliacao();
    const trimestre = calcularTrimestre(mesReferencia, anoReferencia);
    
    // Filtra dados do prestador no trimestre
    const dadosPrestador = dados.filter(function(d) {
      return d.cnes.toString().trim() === cnes.toString().trim() &&
        trimestre.some(function(t) {
          return d.ano === t.ano && d.mes === t.mes;
        });
    });
    
    if (dadosPrestador.length === 0) {
      return { erro: true, mensagem: 'Prestador não encontrado no período.' };
    }
    
    // Agrupa por categoria
    const categorias = {};
    
    dadosPrestador.forEach(function(d) {
      const categoria = [d.tipo_fixado, d.complexidade, d.modalidade].filter(Boolean).join(' | ');
      
      if (!categorias[categoria]) {
        categorias[categoria] = {
          nome: categoria,
          tipo_fixado: d.tipo_fixado,
          complexidade: d.complexidade,
          modalidade: d.modalidade,
          meses: []
        };
      }
      
      categorias[categoria].meses.push({
        ano: d.ano,
        mes: d.mes,
        mesNome: getMesNome(d.mes),
        meta: Math.round(parseFloat(d.meta) || 0),
        producao: Math.round(parseFloat(d.producao) || 0),
        desempenho: Math.round((parseFloat(d.desempenho) || 0) * 100),
        classificacao: d.classificacao
      });
    });
    
    // Ordena meses em cada categoria
    Object.keys(categorias).forEach(function(cat) {
      categorias[cat].meses.sort(function(a, b) {
        return (a.ano * 100 + a.mes) - (b.ano * 100 + b.mes);
      });
    });
    
    return {
      erro: false,
      cnes: cnes,
      nome_prestador: dadosPrestador[0].nome_prestador,
      categorias: Object.values(categorias),
      trimestre: trimestre
    };
    
  } catch (error) {
    Logger.log('>>> ERRO em getDetalheAvaliacaoPrestador: ' + error.toString());
    return { erro: true, mensagem: error.toString() };
  }
}

/**
 * Calcula o trimestre (mês atual + 2 anteriores)
 */
function calcularTrimestre(mes, ano) {
  const trimestre = [];
  
  for (let i = 0; i < 3; i++) {
    let m = mes - i;
    let a = ano;
    
    while (m <= 0) {
      m += 12;
      a--;
    }
    
    trimestre.unshift({ mes: m, ano: a, mesNome: getMesNome(m) });
  }
  
  return trimestre;
}

/**
 * Classifica desempenho com base no percentual
 */
function classificarDesempenho(desempenho) {
  if (desempenho >= 0.9) return 'Ótimo';
  if (desempenho >= 0.8) return 'Bom';
  if (desempenho >= 0.7) return 'Regular';
  return 'Insatisfatório';
}

/**
 * Retorna nome do mês
 */
function getMesNome(mes) {
  const meses = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 
                'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
  return meses[mes] || '';
}

/**
 * Exporta relatório de avaliação para Excel
 */
function exportarRelatorioAvaliacao(mesReferencia, anoReferencia, filtroPrestador) {
  try {
    Logger.log('>>> exportarRelatorioAvaliacao: INÍCIO');
    
    const dados = getAvaliacaoPrestadores(mesReferencia, anoReferencia);
    
    if (dados.erro) {
      return { sucesso: false, mensagem: dados.mensagem };
    }
    
    if (!dados.prestadores || dados.prestadores.length === 0) {
      return { sucesso: false, mensagem: 'Nenhum dado para exportar.' };
    }
    
    // Aplica filtro se informado
    let prestadores = dados.prestadores;
    if (filtroPrestador && filtroPrestador.trim() !== '') {
      const filtroLower = filtroPrestador.toLowerCase().trim();
      prestadores = prestadores.filter(function(p) {
        return p.nome_prestador.toLowerCase().indexOf(filtroLower) !== -1;
      });
    }
    
    // Cria planilha
    const mesesNomes = ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
    const nomeMes = mesesNomes[mesReferencia - 1];
    const nomeArquivo = 'Avaliacao_Prestadores_' + nomeMes + '_' + anoReferencia + '_' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd_HHmm');
    
    const ss = SpreadsheetApp.create(nomeArquivo);
    
    // ========== ABA 1: RESUMO POR PRESTADOR ==========
    const sheetResumo = ss.getActiveSheet();
    sheetResumo.setName('Resumo por Prestador');
    
    // Cabeçalho
    sheetResumo.getRange('A1').setValue('AVALIAÇÃO DE PRESTADORES - TRIMESTRE: ' + dados.trimestre.map(function(t) { return t.mesNome; }).join(' / ') + ' ' + anoReferencia);
    sheetResumo.getRange('A1').setFontSize(14).setFontWeight('bold').setBackground('#8B5CF6').setFontColor('white');
    sheetResumo.getRange('A1:H1').merge();
    
    sheetResumo.getRange('A2').setValue('Gerado em: ' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'dd/MM/yyyy HH:mm'));
    
    // Cabeçalhos da tabela
    const headersResumo = ['CNES', 'Prestador', 'Meta Total', 'Produção Total', 'Desempenho %', 'Classificação', 'Ótimo', 'Bom', 'Regular', 'Insatisf.', 'Status'];
    sheetResumo.getRange(4, 1, 1, headersResumo.length).setValues([headersResumo]);
    sheetResumo.getRange(4, 1, 1, headersResumo.length).setFontWeight('bold').setBackground('#A78BFA').setFontColor('white');
    
    // Dados
    const linhasResumo = prestadores.map(function(p) {
      var statusTexto = '';
      if (p.status === 'ok') statusTexto = '✅ Satisfatório';
      else if (p.status === 'atencao') statusTexto = '⚠️ Atenção';
      else statusTexto = '❌ Crítico';
      
      return [
        p.cnes,
        p.nome_prestador,
        p.totais.meta,
        p.totais.producao,
        p.desempenhoGeral + '%',
        p.classificacaoGeral,
        p.totais.qtdOtimo,
        p.totais.qtdBom,
        p.totais.qtdRegular,
        p.totais.qtdInsatisfatorio,
        statusTexto
      ];
    });
    
    if (linhasResumo.length > 0) {
      sheetResumo.getRange(5, 1, linhasResumo.length, headersResumo.length).setValues(linhasResumo);
      sheetResumo.getRange(5, 3, linhasResumo.length, 2).setNumberFormat('#,##0');
    }
    
    // Formatação condicional
    for (var row = 5; row < 5 + linhasResumo.length; row++) {
      var status = sheetResumo.getRange(row, 11).getValue();
      if (status.indexOf('Satisfatório') !== -1) {
        sheetResumo.getRange(row, 1, 1, headersResumo.length).setBackground('#D1FAE5');
      } else if (status.indexOf('Atenção') !== -1) {
        sheetResumo.getRange(row, 1, 1, headersResumo.length).setBackground('#FEF3C7');
      } else if (status.indexOf('Crítico') !== -1) {
        sheetResumo.getRange(row, 1, 1, headersResumo.length).setBackground('#FEE2E2');
      }
    }
    
    // Auto-ajusta colunas
    for (var i = 1; i <= headersResumo.length; i++) {
      sheetResumo.autoResizeColumn(i);
    }
    
    // ========== ABA 2: DETALHAMENTO MENSAL ==========
    const sheetDetalhe = ss.insertSheet('Detalhamento Mensal');
    
    // Cabeçalho
    sheetDetalhe.getRange('A1').setValue('DETALHAMENTO MENSAL - ' + dados.trimestre.map(function(t) { return t.mesNome; }).join(' / ') + ' ' + anoReferencia);
    sheetDetalhe.getRange('A1').setFontSize(14).setFontWeight('bold').setBackground('#8B5CF6').setFontColor('white');
    sheetDetalhe.getRange('A1:G1').merge();
    
    // Cabeçalhos da tabela
    const headersDetalhe = ['CNES', 'Prestador', 'Mês', 'Meta', 'Produção', 'Desempenho %', 'Status'];
    sheetDetalhe.getRange(3, 1, 1, headersDetalhe.length).setValues([headersDetalhe]);
    sheetDetalhe.getRange(3, 1, 1, headersDetalhe.length).setFontWeight('bold').setBackground('#A78BFA').setFontColor('white');
    
    // Dados detalhados
    const linhasDetalhe = [];
    prestadores.forEach(function(p) {
      p.mesesArray.forEach(function(m) {
        var statusMes = '';
        if (m.qtdInsatisfatorio > 0) statusMes = '❌';
        else if (m.qtdRegular > 0) statusMes = '⚠️';
        else statusMes = '✅';
        
        linhasDetalhe.push([
          p.cnes,
          p.nome_prestador,
          m.mesNome + '/' + m.ano,
          m.meta,
          m.producao,
          m.desempenho + '%',
          statusMes
        ]);
      });
    });
    
    if (linhasDetalhe.length > 0) {
      sheetDetalhe.getRange(4, 1, linhasDetalhe.length, headersDetalhe.length).setValues(linhasDetalhe);
      sheetDetalhe.getRange(4, 4, linhasDetalhe.length, 2).setNumberFormat('#,##0');
    }
    
    // Formatação condicional
    for (var rowD = 4; rowD < 4 + linhasDetalhe.length; rowD++) {
      var statusD = sheetDetalhe.getRange(rowD, 7).getValue();
      if (statusD === '✅') {
        sheetDetalhe.getRange(rowD, 1, 1, headersDetalhe.length).setBackground('#D1FAE5');
      } else if (statusD === '⚠️') {
        sheetDetalhe.getRange(rowD, 1, 1, headersDetalhe.length).setBackground('#FEF3C7');
      } else {
        sheetDetalhe.getRange(rowD, 1, 1, headersDetalhe.length).setBackground('#FEE2E2');
      }
    }
    
    // Auto-ajusta colunas
    for (var j = 1; j <= headersDetalhe.length; j++) {
      sheetDetalhe.autoResizeColumn(j);
    }
    
    // Força gravação
    SpreadsheetApp.flush();
    Utilities.sleep(500);
    
    Logger.log('>>> Relatório de avaliação exportado: ' + nomeArquivo);
    
    return {
      sucesso: true,
      url: 'https://docs.google.com/spreadsheets/d/' + ss.getId(),
      mensagem: 'Relatório gerado com sucesso!'
    };
    
  } catch (error) {
    Logger.log('>>> ERRO ao exportar avaliação: ' + error.toString());
    return { sucesso: false, mensagem: error.toString() };
  }
}


/**
 * Converte diferentes formatos de data para objeto Date
 */
function converterParaData(valor) {
  if (!valor) return null;
  
  // Se já é Date
  if (valor instanceof Date) {
    return valor;
  }
  
  // Se é string
  if (typeof valor === 'string') {
    valor = valor.trim();
    
    // Formato dd/MM/yyyy
    if (/^\d{2}\/\d{2}\/\d{4}$/.test(valor)) {
      const partes = valor.split('/');
      return new Date(partes[2], partes[1] - 1, partes[0]);
    }
    
    // Formato yyyy-MM-dd
    if (/^\d{4}-\d{2}-\d{2}/.test(valor)) {
      const partes = valor.substring(0, 10).split('-');
      return new Date(partes[0], partes[1] - 1, partes[2]);
    }
    
    // Tenta parsing padrão
    try {
      const data = new Date(valor);
      if (!isNaN(data.getTime())) {
        return data;
      }
    } catch (e) {
      return null;
    }
  }
  
  // Se é número (serial do Excel)
  if (typeof valor === 'number') {
    return new Date((valor - 25569) * 86400 * 1000);
  }
  
  return null;
}
